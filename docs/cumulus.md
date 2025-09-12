
```
cumulus@SN3420M-01:mgmt:~$ nv show platform transceiver brief # after 5.11
Transceiver  Identifier  Vendor name      Vendor PN         Vendor SN     Vendor revision
-----------  ----------  ---------------  ----------------  ------------  ---------------
swp1         SFP         FINISAR CORP.    FTLX8571D3BCL-HP  MU50PR6       A        
swp2         SFP         FOXCONN          CUFCP32-CHB01-EF  CN02KBG0N0    A        
swp49        QSFP+       Arista Networks  CAB-Q-Q-3M        ADY17120009K  20   

cumulus@SN3420M-01:mgmt:~$ nv show platform transceiver swp1 # before 5.11
cable-type                  : Optical module
supported-cable-length      : 30m om1, 80m om2, 300m om3, 0m om4, 0m om5
supported-cable-length-smf  : 0m
diagnostics-status          : Diagnostic Data Available
status                      : plugged_enabled
error-status                : N/A
vendor-date-code            : 15080732
identifier                  : SFP
vendor-rev                  : A
vendor-name                 : FINISAR CORP.
vendor-pn                   : FTLX8571D3BCL-HP
vendor-sn                   : MU50PR6
vendor-oui                  : 00:90:65
temperature:
  temperature               : 29.18 C
  high-alarm-threshold      : 78.00 C
  low-alarm-threshold       : -13.00 C
  high-warning-threshold    : 73.00 C
  low-warning-threshold     : -8.00 C
```