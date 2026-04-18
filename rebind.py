#!/usr/bin/env python3

import argparse
import re
import sys
import subprocess
from pprint import pprint
from pathlib import Path

flags = argparse.ArgumentParser(description="Rebind rust bindgens")
flags.add_argument("source", type=str, nargs="+", help="Bindgen source to process")
flags.add_argument(
    "--outdir", "-o", type=Path, default="", help="Destination of output files"
)
flags.add_argument(
    "--rustfmt",
    default=True,
    action=argparse.BooleanOptionalAction,
    help="Format files with rustfmt",
)
flags.add_argument(
    "--with-async",
    default=False,
    action=argparse.BooleanOptionalAction,
    help="Include cryptolib 'async' functions",
)


class Cryptolib(object):
    ZEROCOPY = (
        "zerocopy::KnownLayout,"
        + "zerocopy::Immutable,"
        + "zerocopy::FromBytes,"
        + "zerocopy::IntoBytes,"
    )
    PRIMITIVE = [
        "u8",
        "u16",
        "u32",
        "u64",
        "usize",
        "i8",
        "i16",
        "i32",
        "i64",
        "isize",
    ]
    KEY_MATERIAL = {
        # Algorithm: (public key size, blinded keyblob size)
        "EcdsaP256": (32 * 2, (32 + 8) * 2),
        "EcdsaP384": (48 * 2, (48 + 8) * 2),
        "Ed25519": (32 * 2, (32 + 8) * 2),
        "X25519": (32 * 2, (32 + 8) * 2),
        "Rsa2048": (256, 768),
        "Rsa3072": (384, 1152),
        "Rsa4096": (512, 1536),
        "Aes": (32, 64),
    }

    def __init__(self, bindgen, with_async=False):
        self.bindgen = bindgen
        self.with_async = False
        self.renames = {}
        self.datatypes = []
        self.interface = []
        self.impl = []
        self.misc = []
        self.lib = []

    @staticmethod
    def to_title_case(text):
        """Convert a symbol to TitleCase."""
        capitalize = True
        value = []
        for ch in text:
            if ch == "_":
                capitalize = True
                continue
            if capitalize:
                ch = ch.upper()
                capitalize = False
            value.append(ch)
        if value[0].isdigit():
            value.insert("_", 0)
        return "".join(value)

    def make_ref(self, mutref, ty):
        """Maybe make a type into a reference."""
        if mutref and ty.startswith("&"):
            return ty.replace("&", mutref)
        if not mutref and ty == "HashDigest":
            mutref = "&"
        return mutref + ty

    def resolve(self, ty):
        """Resolve an otcrypto type into its re-binded typename."""
        mutref = ""
        if ty.startswith("*"):
            (muta, ty) = ty.split()
            if muta == "*mut":
                mutref = "&mut "
            elif muta == "*const":
                mutref = "&"
            else:
                raise Exception(f"Unknown pointer kind: {muta}")

        aty = self.bindgen.alias.get(ty)
        if ty in self.renames:
            return self.make_ref(mutref, self.renames[ty])
        if aty in self.renames:
            return self.make_ref(mutref, self.renames[aty])
        return self.make_ref(mutref, ty)

    def gen_header(self):
        self.datatypes.append(
            """
            use crate::otcrypto::*;
            use crate::misc::GetPointer;
            """
        )
        self.misc.append(
            """
            use crate::otcrypto::*;
            """
        )
        self.interface.append(
            """
            use crate::datatypes::*;
            """
        )
        self.impl.append(
            """
            use crate::otcrypto::*;
            use crate::datatypes::*;
            use crate::misc::GetPointer;
            use crate::interface::CryptoInterface;
            """
        )
        self.lib.append(
            """
            #![no_std]
            mod datatypes;
            mod implementation;
            mod interface;
            mod misc;
            pub mod otcrypto;

            pub use datatypes::*;
            pub use implementation::OtCrypto;
            pub use interface::CryptoInterface;
            """
        )

    def gen_private_traits(self):
        self.misc.append(
            """
            pub(crate) trait GetPointer {
              type Target;
              fn as_ptr(&self) -> *const Self::Target;
              fn as_mut_ptr(&mut self) -> *mut Self::Target;
            }
            """
        )
        for name in self.PRIMITIVE:
            self.misc.append(
                f"""
                    impl GetPointer for {name} {{
                      type Target = {name};
                      fn as_ptr(&self) -> *const {name} {{
                        self as *const {name}
                      }}
                      fn as_mut_ptr(&mut self) -> *mut {name} {{
                        self as *mut {name}
                      }}
                    }}
                """
            )

    def gen_slice_structs(self):
        self.renames.update(
            {
                "otcrypto_byte_buf": "&mut [u8]",
                "otcrypto_const_byte_buf": "&[u8]",
                "otcrypto_word32_buf": "&mut [u8]",
                "otcrypto_const_word32_buf": "&[u8]",
            }
        )
        self.misc.append(
            """
               impl From<&mut [u8]> for otcrypto_byte_buf {
                 fn from(buf: &mut [u8]) -> Self {
                   Self {
                     data: buf.as_mut_ptr(),
                     len: buf.len(),
                   }
                 }
               }
               impl From<&[u8]> for otcrypto_const_byte_buf {
                 fn from(buf: &[u8]) -> Self {
                   Self {
                     data: buf.as_ptr(),
                     len: buf.len(),
                   }
                 }
               }

               // TODO: I'm cheating and accepting a u8 slice here.
               impl From<&mut [u8]> for otcrypto_word32_buf {
                 fn from(buf: &mut [u8]) -> Self {
                   Self {
                     data: buf.as_mut_ptr() as *mut u32,
                     len: buf.len() / 4,
                   }
                 }
               }
               impl From<&[u8]> for otcrypto_const_word32_buf {
                 fn from(buf: &[u8]) -> Self {
                   Self {
                     data: buf.as_ptr() as *const u32,
                     len: buf.len() / 4,
                   }
                 }
               }
            """
        )

    def gen_error_enum(self):
        self.gen_enum(
            "otcrypto_status_value", "Error", "StatusValue", vis="pub", inner_type="i32"
        )
        self.renames["otcrypto_status_t"] = "CryptoResult"
        self.datatypes.append(
            """
                pub type CryptoResult = ::core::result::Result<(), Error>;
                impl From<otcrypto_status_t> for CryptoResult {
                  fn from(sts: otcrypto_status_t) -> Self {
                     let e = Error(sts.value);
                     if e == Error::Ok {
                       Ok(())
                     } else {
                       Err(e)
                     }
                  }
                }
            """
        )

        self.datatypes.append(
            """
                impl From<Error> for pw_status::Error {
                  fn from(e: Error) -> Self {
                    unsafe {
                      // SAFETY: the low bits of Error are identical
                      // to pw_status::Error codes.
                      core::mem::transmute(e.0 & 0x1f)
                    }
                  }
                }
            """
        )

    def gen_enum(
        self, name, newname=None, regexname=None, vis="pub(crate)", inner_type="u32"
    ):
        if not newname:
            newname = self.to_title_case(name.replace("otcrypto_", ""))
        if not regexname:
            regexname = newname
        if regexname == "HashMode":
            regexname = "Hash(?:Xof)?Mode"

        self.renames[name] = newname
        self.gen_doc(name, self.datatypes)
        self.datatypes.append(
            f"#[derive(Debug, Clone, Copy, PartialEq, Eq, {self.ZEROCOPY})]"
        )
        self.datatypes.append("#[repr(C)]")
        self.datatypes.append(f"pub struct {newname}({vis} {inner_type});")
        self.gen_enum_impl(name, newname, regexname)
        self.datatypes.append(
            f"""
                impl From<{newname}> for {inner_type} {{
                  fn from(v: {newname}) -> Self {{
                    v.0
                  }}
                }}
                impl GetPointer for {newname} {{
                  type Target = {inner_type};
                  fn as_ptr(&self) -> *const {inner_type} {{
                    &self.0 as *const {inner_type}
                  }}
                  fn as_mut_ptr(&mut self) -> *mut {inner_type} {{
                    &mut self.0 as *mut {inner_type}
                  }}
                }}
            """
        )

    def gen_enum_impl(self, name, newname, regexname):
        values = []
        for vname, ty, value in self.bindgen.consts:
            if ty == name:
                vname = re.sub(f".*{regexname}(.*)", r"\1", vname)
                values.append((vname, value))

        self.datatypes.append("#[allow(non_upper_case_globals)]")
        self.datatypes.append(f"impl {newname} {{")
        for ename, value in values:
            if ename[0].isdigit():
                ename = "_" + ename
            self.datatypes.append(f"    pub const {ename}: {newname} = Self({value});")
        self.datatypes.append("}\n")

    def gen_struct_ptr(self, name, newname, generic_constraints={}):
        generics = []
        constraints = []
        for ty, constraint in generic_constraints.items():
            generics.append(ty)
            constraints.append(f"{ty}: {constraint}")
        if generics:
            generics = ", ".join(generics)
            generics = f"<{generics}>"
            constraints = ", ".join(constraints)
            constraints = f"<{constraints}>"
        else:
            generics = ""
            constraints = ""

        self.datatypes.append(
            f"""
                impl{constraints} GetPointer for {newname}{generics} {{
                  type Target = {name};
                  fn as_ptr(&self) -> *const {name} {{
                    self as *const {newname}{generics} as *const {name}
                  }}
                  fn as_mut_ptr(&mut self) -> *mut {name} {{
                    self as *mut {newname}{generics} as *mut {name}
                  }}
                }}
            """
        )

    def gen_struct_otcrypto_blinded_key(self, name, newname=None):
        if not newname:
            newname = self.to_title_case(name.replace("otcrypto_", ""))
        (_, tparam, _) = name.split("_")
        tsize = tparam.upper() + "_SIZE"
        tparam = tparam.capitalize() + "Storage"

        self.renames[name] = newname
        self.gen_doc(name, self.datatypes)
        self.datatypes.append(f"#[derive(Debug, Clone, {self.ZEROCOPY})]")
        self.datatypes.append("#[repr(C)]")
        self.datatypes.append(f"pub struct {newname} {{")
        fields = self.bindgen.structs[name]
        pointer_field = None
        for fname, ty in fields.items():
            if ty == "*mut u32":
                self.datatypes.append(f"    pub {fname}: usize,")
                pointer_field = fname
            else:
                ty = self.resolve(ty)
                self.datatypes.append(f"    pub {fname}: {ty},")
        self.datatypes.append(f"}}")
        self.gen_struct_ptr(name, newname)
        self.datatypes.append(
            f"""
            impl {newname} {{
              pub fn with_key_material(&mut self, km: &[u8]) -> &mut Self {{
                // TODO: make sure km is the right size.
                // TODO: Capture km's lifetime and attach it to the returned self reference.
                self.{pointer_field} = km.as_ptr() as usize;
                self
              }}
              pub fn with_internal_key_material(&mut self) -> &mut Self {{
                let base = &raw const *self as usize;
                self.{pointer_field} = base + core::mem::size_of::<Self>();
                self
              }}
            }}
            """
        )

    gen_struct_otcrypto_unblinded_key = gen_struct_otcrypto_blinded_key

    def gen_struct(self, name, newname=None):
        if not newname:
            newname = self.to_title_case(name.replace("otcrypto_", ""))
        self.renames[name] = newname
        self.gen_doc(name, self.datatypes)
        self.datatypes.append(f"#[derive(Debug, Clone, {self.ZEROCOPY})]")
        self.datatypes.append("#[repr(C)]")
        self.datatypes.append(f"pub struct {newname} {{")
        fields = self.bindgen.structs[name]
        for fname, ty in fields.items():
            ty = self.resolve(ty)
            self.datatypes.append(f"    pub {fname}: {ty},")
        self.datatypes.append(f"}}")
        self.gen_struct_ptr(name, newname)
        self.datatypes.append(
            f"""
                impl From<{newname}> for {name} {{
                  fn from(v: {newname}) -> Self {{
                    unsafe {{ core::mem::transmute(v) }}
                  }}
                }}
            """
        )

    def gen_hash_digest(self):
        self.renames["otcrypto_hash_digest"] = "HashDigest"
        self.datatypes.append(
            f"""
                #[derive(Debug, {self.ZEROCOPY})]
                #[repr(C)]
                pub struct HashDigest {{
                  pub mode: HashMode,
                  pub digest: [u32],
                }}

                impl From<&HashDigest> for otcrypto_hash_digest {{
                  fn from(v: &HashDigest) -> Self {{
                    otcrypto_hash_digest {{
                      mode: v.mode.into(),
                      data: v.digest.as_ptr() as *mut u32,
                      len: v.digest.len(),
                    }}
                  }}
                }}
                impl From<&mut HashDigest> for otcrypto_hash_digest {{
                  fn from(v: &mut HashDigest) -> Self {{
                    otcrypto_hash_digest {{
                      mode: v.mode.into(),
                      data: v.digest.as_mut_ptr(),
                      len: v.digest.len(),
                    }}
                  }}
                }}
            """
        )

    def gen_enums(self):
        dq = [
            "otcrypto_status_value",
        ]
        for item in filter(
            lambda x: x not in dq,
            (
                alias
                for alias, target in self.bindgen.alias.items()
                if target == "::core::ffi::c_uint"
            ),
        ):
            self.gen_enum(item)

    def gen_structs(self):
        dq = [
            "otcrypto_byte_buf",
            "otcrypto_const_byte_buf",
            "otcrypto_const_word32_buf",
            "otcrypto_hash_digest",
            "otcrypto_word32_buf",
            "status",
        ]
        for item in filter(lambda x: x not in dq, self.bindgen.structs.keys()):
            gen = getattr(self, f"gen_struct_{item}", self.gen_struct)
            gen(item)

    def need_constraints(self, fn):
        constraints = {}
        params = self.bindgen.fns[fn]
        # TODO: Examine the params.  If they need constraints, add them
        # to the `constraints` dict.
        if constraints:
            constraints = ", ".join(f"{t}: {c}" for t, c in constraints.items())
            return f"<{constraints}>"
        else:
            return ""

    def gen_trait_fns(self):
        self.interface.append("#[allow(unused_variables)]")
        self.interface.append(f"pub trait CryptoInterface {{")
        for fn, param in self.bindgen.fns.items():
            if not self.with_async and "async" in fn:
                continue
            constraints = self.need_constraints(fn)
            name = fn.replace("otcrypto_", "")
            self.gen_doc(fn, self.interface)
            self.interface.append(f"    fn {name}{constraints}(")
            for pname, ty in param.items():
                if pname == "__ret":
                    continue
                ty = self.resolve(ty)
                self.interface.append(f"        {pname}: {ty},")
            ret = self.resolve(param["__ret"])
            self.interface.append(f"    ) -> {ret} {{ unimplemented!(); }}")
        self.interface.append(f"}}")

    def gen_impl_fns(self):
        SLICE_TYPES = [
            "otcrypto_byte_buf_t",
            "otcrypto_const_byte_buf_t",
            "otcrypto_word32_buf_t",
            "otcrypto_const_word32_buf_t",
        ]

        self.impl.append("pub struct OtCrypto;")
        self.impl.append(f"impl CryptoInterface for OtCrypto {{")
        for fn, param in self.bindgen.fns.items():
            if not self.with_async and "async" in fn:
                continue
            constraints = self.need_constraints(fn)
            name = fn.replace("otcrypto_", "")
            prework = []
            postwork = []
            self.impl.append(f"    fn {name}{constraints}(")
            for pname, ty in param.items():
                if pname == "__ret":
                    continue
                ty = self.resolve(ty)
                self.impl.append(f"        {pname}: {ty},")
                if ty == "&mut HashDigest":
                    prework = [
                        f"let mut {pname}_ = otcrypto_hash_digest::from(&mut *{pname});"
                    ]
                    postwork = [f"{pname}.mode = HashMode({pname}_.mode);"]

            ret = self.resolve(param["__ret"])
            self.impl.append(f"    ) -> {ret} {{")
            self.impl.extend(prework)
            self.impl.append(f"        let result = unsafe {{ {fn}(")

            for pname, ty in param.items():
                if pname == "__ret":
                    continue
                if ty in SLICE_TYPES:
                    self.impl.append(f"            {ty}::from({pname}),")
                elif ty.startswith("*mut otcrypto_hash_digest_t"):
                    self.impl.append(f"            &mut {pname}_,")
                elif ty.startswith("otcrypto_hash_digest_t"):
                    self.impl.append(
                        f"            otcrypto_hash_digest::from({pname}),"
                    )
                elif ty.startswith("*const"):
                    self.impl.append(f"            {pname}.as_ptr(),")
                elif ty.startswith("*mut"):
                    self.impl.append(f"            {pname}.as_mut_ptr(),")
                else:
                    self.impl.append(f"            {pname}.into(),")
            self.impl.append(f"       ) }};")
            self.impl.extend(postwork)
            self.impl.append(f"    result.into()")
            self.impl.append(f"    }}")
        self.impl.append(f"}}")

    def gen_doc(self, name, source):
        if doc := self.bindgen.doc.get(name):
            # Lets try reformatting the docs
            text = re.match(r'#\[doc\s*=\s*"(.*)"]', doc)
            text = "///" + text.group(1).replace(r"\n", "\n///")
            source.append(text)

    def generate(self):
        self.gen_header()
        self.gen_error_enum()
        self.gen_private_traits()
        self.gen_enums()
        self.gen_slice_structs()
        self.gen_structs()
        self.gen_hash_digest()
        self.gen_trait_fns()
        self.gen_impl_fns()

    def emit(self, outdir: Path, rustfmt: bool):
        with open(outdir / "datatypes.rs", "wt") as f:
            f.write("\n".join(self.datatypes))
        with open(outdir / "misc.rs", "wt") as f:
            f.write("\n".join(self.misc))
        with open(outdir / "interface.rs", "wt") as f:
            f.write("\n".join(self.interface))
        with open(outdir / "implementation.rs", "wt") as f:
            f.write("\n".join(self.impl))
        with open(outdir / "lib.rs", "wt") as f:
            f.write("\n".join(self.lib))

        if rustfmt:
            subprocess.run(["rustfmt", outdir / "lib.rs"])


REPR = r"#\[repr\([^)]+\)]\s*"
DERIVE = r"#\[derive\([^)]+\)]\s*"
DOC = r'(?P<doc>#\[doc\s*=\s*"[^"]+"])?\s*(?:' + REPR + ")?(?:" + DERIVE + ")?"


class Rebinder(object):

    TYPE_ALIAS = re.compile(
        DOC + r"pub\s+type\s+(?P<alias>\w+)\s+=\s+(?P<name>[^;]+);", re.M | re.DOTALL
    )
    USE_ALIAS = re.compile(
        DOC + r"pub\s+use\s+self::(?P<name>\w+)\s+as\s+(?P<alias>[^;]+);",
        re.M | re.DOTALL,
    )
    CONST_VAL = re.compile(
        DOC + r"pub\s+const\s+(?P<name>\w+):\s+(?P<type>\w+)\s+=\s+(?P<value>[^;]+);",
        re.M | re.DOTALL,
    )
    FN_DEF = re.compile(
        DOC
        + r"pub\s+fn\s+(?P<name>\w+)\s*\(\s*(?P<params>.*?)\)\s*(;|\s*->\s*(?P<ret>\w+);)",
        re.M | re.DOTALL,
    )
    STRUCT_DEF = re.compile(
        DOC + r"pub\s+struct\s+(?P<name>\w+)\s*\{\s*(?P<fields>.*?)\}", re.M | re.DOTALL
    )

    def __init__(self):
        self.alias = {}
        self.consts = []
        self.fns = {}
        self.structs = {}
        self.doc = {}
        pass

    def _parse_aliases(self, text):
        for item in self.TYPE_ALIAS.finditer(text):
            self.alias[item.group("alias")] = item.group("name")
            self.doc[item.group("alias")] = item.group("doc")
        for item in self.USE_ALIAS.finditer(text):
            self.alias[item.group("alias")] = item.group("name")
            self.doc[item.group("alias")] = item.group("doc")

    def _parse_consts(self, text):
        for item in self.CONST_VAL.finditer(text):
            self.consts.append(
                (item.group("name"), item.group("type"), item.group("value"))
            )
            self.doc[item.group("name")] = item.group("doc")

    def _parse_fns(self, text):
        for item in self.FN_DEF.finditer(text):
            name = item.group("name")
            params = {}
            for p in item.group("params").split(","):
                p = p.strip()
                if not p:
                    continue
                pname, ty = p.split(":")
                params[pname.strip()] = ty.strip()
            params["__ret"] = item.group("ret")
            self.fns[name] = params
            self.doc[name] = item.group("doc")

    def _parse_structs(self, text):
        for item in self.STRUCT_DEF.finditer(text):
            name = item.group("name")
            fields = {}
            for f in item.group("fields").split(","):
                f = f.strip()
                if not f:
                    continue
                fname, ty = f.split(":")
                fname = fname.replace("pub ", "")
                fields[fname.strip()] = ty.strip()
            self.structs[name] = fields
            self.doc[name] = item.group("doc")

    def parse(self, filename):
        text = open(filename, "rt").read()
        self._parse_aliases(text)
        self._parse_consts(text)
        self._parse_fns(text)
        self._parse_structs(text)


def main(args):
    rebind = Rebinder()
    for f in args.source:
        rebind.parse(f)

    lib = Cryptolib(rebind, args.with_async)
    lib.generate()
    lib.emit(args.outdir, args.rustfmt)


if __name__ == "__main__":
    sys.exit(main(flags.parse_args()))
