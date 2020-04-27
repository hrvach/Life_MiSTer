module row (
   input           clock,
   input    [0:0]  shiftin,
   output   [0:0]  shiftout
);

   altshift_taps  ALTSHIFT_TAPS_component (
            .clock (clock),
            .shiftin (shiftin),
            .shiftout (shiftout)
            );
   defparam
      ALTSHIFT_TAPS_component.intended_device_family = "Cyclone V",
      ALTSHIFT_TAPS_component.lpm_hint = "RAM_BLOCK_TYPE=M10K",
      ALTSHIFT_TAPS_component.lpm_type = "altshift_taps",
      ALTSHIFT_TAPS_component.number_of_taps = 1,
      ALTSHIFT_TAPS_component.tap_distance = 2198,
      ALTSHIFT_TAPS_component.width = 1;

endmodule


module fb (
   input           clock,
   input    [0:0]  shiftin,
   output   [0:0]  shiftout
);

   altshift_taps  ALTSHIFT_TAPS_component (
            .clock (clock),
            .shiftin (shiftin),
            .shiftout (shiftout)
            );
   defparam
      ALTSHIFT_TAPS_component.intended_device_family = "Cyclone V",
      ALTSHIFT_TAPS_component.lpm_hint = "RAM_BLOCK_TYPE=M10K",
      ALTSHIFT_TAPS_component.lpm_type = "altshift_taps",
      ALTSHIFT_TAPS_component.number_of_taps = 1,
      ALTSHIFT_TAPS_component.tap_distance = 2472798, // 2069758,
      ALTSHIFT_TAPS_component.width = 1;


endmodule
