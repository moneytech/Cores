module redor52
(
	input [5:0] a,
	input [51:0] b,
	output reg o
);

	always @(a,b)
	case (a)
	6'd0:	o =  b[0];
	6'd1:	o = |b[1:0];
	6'd2:	o = |b[2:0];
	6'd3:	o = |b[3:0];
	6'd4:	o = |b[4:0];
	6'd5:	o = |b[5:0];
	6'd6:	o = |b[6:0];
	6'd7:	o = |b[7:0];
	6'd8:	o = |b[8:0];
	6'd9:	o = |b[9:0];
	6'd10:	o = |b[10:0];
	6'd11:	o = |b[11:0];
	6'd12:	o = |b[12:0];
	6'd13:	o = |b[13:0];
	6'd14:	o = |b[14:0];
	6'd15:	o = |b[15:0];
	6'd16:	o = |b[16:0];
	6'd17:	o = |b[17:0];
	6'd18:	o = |b[18:0];
	6'd19:	o = |b[19:0];
	6'd20:	o = |b[20:0];
	6'd21:	o = |b[21:0];
	6'd22:	o = |b[22:0];
	6'd23:	o = |b[23:0];
	6'd24:	o = |b[24:0];
	6'd25:	o = |b[25:0];
	6'd26:	o = |b[26:0];
	6'd27:	o = |b[27:0];
	6'd28:	o = |b[28:0];
	6'd29:	o = |b[29:0];
	6'd30:	o = |b[30:0];
	6'd31:	o = |b[31:0];
	6'd32:	o = |b[32:0];
	6'd33:	o = |b[33:0];
	6'd34:	o = |b[34:0];
	6'd35:	o = |b[35:0];
	6'd36:	o = |b[36:0];
	6'd37:	o = |b[37:0];
	6'd38:	o = |b[38:0];
	6'd39:	o = |b[39:0];
	6'd40:	o = |b[40:0];
	6'd41:	o = |b[41:0];
	6'd42:	o = |b[42:0];
	6'd43:	o = |b[43:0];
	6'd44:	o = |b[44:0];
	6'd45:	o = |b[45:0];
	6'd46:	o = |b[46:0];
	6'd47:	o = |b[47:0];
	6'd48:	o = |b[48:0];
	6'd49:	o = |b[49:0];
	6'd50:	o = |b[50:0];
	default:	o = |b[51:0];
	endcase

endmodule
