// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class chip_sw_all_escalation_resets_vseq extends chip_sw_base_vseq;
  `uvm_object_utils(chip_sw_all_escalation_resets_vseq)

  `uvm_object_new

  // This associates a regex used to match the instance path and an alert number.
  typedef struct {
    string ip_inst_regex;
    byte alert_num;
  } ip_fatal_alert_t;

  ip_fatal_alert_t ip_alerts[] = '{
    '{"*aes*prim_reg_we_check*", TopDarjeelingAlertIdAesFatalFault},
    '{"*aon_timer*prim_reg_we_check*", TopDarjeelingAlertIdAonTimerAonFatalFault},
    '{"*clkmgr*prim_reg_we_check*", TopDarjeelingAlertIdClkmgrAonFatalFault},
    '{"*csrng*prim_reg_we_check*", TopDarjeelingAlertIdCsrngFatalAlert},
    '{"*edn0*prim_reg_we_check*", TopDarjeelingAlertIdEdn0FatalAlert},
    '{"*edn1*prim_reg_we_check*", TopDarjeelingAlertIdEdn1FatalAlert},
    '{"*gpio*prim_reg_we_check*", TopDarjeelingAlertIdGpioFatalFault},
    '{"*hmac*prim_reg_we_check*", TopDarjeelingAlertIdHmacFatalFault},
    '{"*i2c0*prim_reg_we_check*", TopDarjeelingAlertIdI2c0FatalFault},
    '{"*keymgr_dpe*prim_reg_we_check*", TopDarjeelingAlertIdKeymgrDpeFatalFaultErr},
    '{"*kmac*prim_reg_we_check*", TopDarjeelingAlertIdKmacFatalFaultErr},
    // TODO TopDarjeelingAlertIdLcCtrlFatalProgError: done in sw/device/tests/sim_dv/lc_ctrl_program_error.c?
    '{"*lc_ctrl*state_regs*", TopDarjeelingAlertIdLcCtrlFatalStateError},
    '{"*lc_ctrl*prim_reg_we_check*", TopDarjeelingAlertIdLcCtrlFatalBusIntegError},
    '{"*otbn*prim_reg_we_check*", TopDarjeelingAlertIdOtbnFatal},
    // TopDarjeelingAlertIdOtpCtrlFatalMacroError: done in chip_sw_otp_ctrl_escalation_vseq
    '{"*otp_ctrl.u_otp.*u_state_regs", TopDarjeelingAlertIdOtpCtrlFatalPrimOtpAlert},
    '{"*otp_ctrl*u_otp_ctrl_dai*", TopDarjeelingAlertIdOtpCtrlFatalCheckError},
    '{"*otp_ctrl*prim_reg_we_check*", TopDarjeelingAlertIdOtpCtrlFatalBusIntegError},
    '{"*pinmux*prim_reg_we_check*", TopDarjeelingAlertIdPinmuxAonFatalFault},
    '{"*pwrmgr*prim_reg_we_check*", TopDarjeelingAlertIdPwrmgrAonFatalFault},
    '{"*rom_ctrl0*prim_reg_we_check*", TopDarjeelingAlertIdRomCtrl0Fatal},
    '{"*rom_ctrl1*prim_reg_we_check*", TopDarjeelingAlertIdRomCtrl1Fatal},
    '{"*rstmgr*prim_reg_we_check*", TopDarjeelingAlertIdRstmgrAonFatalFault},
    // TopDarjeelingAlertIdRstmgrAonFatalCnstyFault cannot use this test.
    //
    '{"*rv_core_ibex*sw_fatal_err*", TopDarjeelingAlertIdRvCoreIbexFatalSwErr},
    '{"*rv_core_ibex*prim_reg_we_check*", TopDarjeelingAlertIdRvCoreIbexFatalHwErr},
    '{"*rv_dm*prim_reg_we_check*", TopDarjeelingAlertIdRvDmFatalFault},
    '{"*rv_plic*prim_reg_we_check*", TopDarjeelingAlertIdRvPlicFatalFault},
    '{"*rv_timer*prim_reg_we_check*", TopDarjeelingAlertIdRvTimerFatalFault},
    '{"*spi_device*prim_reg_we_check*", TopDarjeelingAlertIdSpiDeviceFatalFault},
    '{"*spi_host0*prim_reg_we_check*", TopDarjeelingAlertIdSpiHost0FatalFault},
    '{"*sram_ctrl_main*prim_reg_we_check*", TopDarjeelingAlertIdSramCtrlMainFatalError},
    '{"*sram_ctrl_ret*prim_reg_we_check*", TopDarjeelingAlertIdSramCtrlRetAonFatalError},
    '{"*uart0*prim_reg_we_check*", TopDarjeelingAlertIdUart0FatalFault}
  };

  rand int ip_index;
  constraint ip_index_c {ip_index inside {[0 : ip_alerts.size() - 1]};}

  // Finds an entry in ip_alerts matching an ip and a security counter-measure by name.
  // It returns the index of the matching entry. It is fatal if no entry is found.
  function int get_ip_index_from_name(string ip_name, string sec_cm);
    string regex = {"*", ip_name, "*", sec_cm, "*"};
    foreach (ip_alerts[i]) begin
      if (ip_alerts[i].ip_inst_regex == regex) return i;
    end
    `uvm_error(`gfn, $sformatf("%0s does not have a matched ip_index", ip_name))
  endfunction

  // Returns the first character index in the string argument that represents
  // the separator (an asterisk, *) between an IP and an associated
  // counter-measure. If no asterisk is found, returns a negative number.
  function int find_separator(string str);
    string sep_char = "*";
    byte sep = sep_char.getc(0);
    for (int i = 0; i < str.len(); i = i + 1) begin
      if (str.getc(i) == sep) begin
        return i;
      end
    end
    return -1;
  endfunction

  virtual task body();
    sec_cm_pkg::sec_cm_base_if_proxy if_proxy;
    ip_fatal_alert_t ip_alert;
    bit [7:0] sw_alert_num[];
    string sec_cm;
    string actual_ip;
    bit show_proxies;

    if ($value$plusargs("inject_fatal_error_for_sec_cm=%s", sec_cm)) begin
      `uvm_info(`gfn, $sformatf("Will inject error on %0s interface", sec_cm), UVM_MEDIUM)
    end else sec_cm = "prim_reg_we_check";
    if ($value$plusargs("inject_fatal_error_for_ip=%s", actual_ip)) begin
      ip_index = get_ip_index_from_name(actual_ip, sec_cm);
    end else begin
      string excluded_ips[$], excluded_ips_append[$];
      int excluded_ip_idxs[$];
      `DV_GET_QUEUE_PLUSARG(excluded_ips, avoid_inject_fatal_error_for_ips)
      `DV_GET_QUEUE_PLUSARG(excluded_ips_append, avoid_ferr_ips_append)
      if (excluded_ips_append.size() > 0) begin
        while(excluded_ips_append.size() > 0)
          excluded_ips.push_back(excluded_ips_append.pop_front());
      end
      foreach (excluded_ips[i]) begin
        int sep_idx = find_separator(excluded_ips[i]);
        if (sep_idx >= 0) begin
          int str_len = excluded_ips[i].len();
          actual_ip = excluded_ips[i].substr(0, sep_idx-1);
          sec_cm = excluded_ips[i].substr(sep_idx + 1, str_len - 1);
        end else begin
          actual_ip = excluded_ips[i];
          sec_cm = "prim_reg_we_check";
        end
        excluded_ip_idxs.push_back(get_ip_index_from_name(actual_ip, sec_cm));
      end
      `DV_CHECK_MEMBER_RANDOMIZE_WITH_FATAL(ip_index, !(ip_index inside {excluded_ip_idxs});)
    end

    if ($value$plusargs("show_proxies=%s", show_proxies)) begin
      if (show_proxies) begin
        foreach (sec_cm_pkg::sec_cm_if_proxy_q[i]) begin
          `uvm_info(`gfn, $sformatf(
                    "sec_cm type %0d at %s",
                    sec_cm_pkg::sec_cm_if_proxy_q[i].sec_cm_type,
                    sec_cm_pkg::sec_cm_if_proxy_q[i].path
                    ), UVM_MEDIUM)
        end
      end
    end
    ip_alert = ip_alerts[ip_index];

    // This sequence will trigger a fatal sec_cm failure.
    super.body();

    `uvm_info(`gfn, $sformatf(
              "Will inject fault for %s, expecting alert %0d",
              ip_alert.ip_inst_regex,
              ip_alert.alert_num
              ), UVM_MEDIUM)

    // Disable scoreboard tl error checks since we will trigger faults which cannot be predicted.
    cfg.en_scb_tl_err_chk = 0;

    // Let SW know the expected alert.
    sw_alert_num = {ip_alert.alert_num};
    sw_symbol_backdoor_overwrite("kExpectedAlertNumber", sw_alert_num);

    ip_alert = ip_alerts[ip_index];

    if (ip_alert.alert_num == TopDarjeelingAlertIdRvCoreIbexFatalSwErr) begin
      `uvm_info(`gfn, "Testing Software fatal alert, no fault to inject", UVM_MEDIUM)
      return;
    end

    if_proxy = sec_cm_pkg::find_sec_cm_if_proxy(.path(ip_alert.ip_inst_regex), .is_regex(1));
    `DV_WAIT(cfg.sw_logger_vif.printed_log == "Ready for fault injection",
             "Timeout waiting for fault injection request.")

    `uvm_info(`gfn, $sformatf(
              "Injecting fault for IP %s, with alert %0d",
              ip_alert.ip_inst_regex,
              ip_alert.alert_num
              ), UVM_MEDIUM);
    if_proxy.inject_fault();
  endtask
endclass
