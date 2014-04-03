// ============================================================================
//        __
//   \\__/ o\    (C) 2013,2014  Robert Finch, Stratford
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@opencores.org
//       ||
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                                                            
// Memory store states
// The store states work for 8, 16 or 32 bit mode              
// ============================================================================
//
// Stores always write through to memory, then optionally update the cache if
// there was a write hit.
STORE1:
	begin
		case(store_what)
		`STW_ACC:	wb_write(0,acc);
		`STW_X:		wb_write(0,x);
		`STW_Y:		wb_write(0,y);
		`STW_PC:	wb_write(0,pc);
		`STW_PC2:	wb_write(0,pc + 32'd2);
		`STW_PCHWI:	wb_write(0,pc+{30'b0,~hwi,1'b0});
		`STW_OPC:	wb_write(0,opc);
		`STW_SR:	wb_write(0,sr);
		`STW_RFA:	wb_write(0,rfoa);
		`STW_RFA8:	wb_write(1,{4{rfoa[7:0]}});
		`STW_A:		wb_write(0,a);
		`STW_B:		wb_write(0,b);
		`STW_CALC:	wb_write(0,res[31:0]);
`ifdef SUPPORT_EM8
		`STW_ACC8:	wb_write(1,{4{acc8}});
		`STW_X8:	wb_write(1,{4{x8}});
		`STW_Y8:	wb_write(1,{4{y8}});
		`STW_Z8:	wb_write(1,{4{8'h00}});
		`STW_PC3124:	wb_write(1,{4{pc[31:24]}});
		`STW_PC2316:	wb_write(1,{4{pc[23:16]}});
		`STW_PC158:		wb_write(1,{4{pc[15:8]}});
		`STW_PC70:		wb_write(1,{4{pc[7:0]}});
		`STW_SR70:		wb_write(1,{4{sr8}});
		`STW_DEF8:		wb_write(1,{4{wdat[7:0]}});
`endif
`ifdef SUPPORT_816
		`STW_DEF70:		wb_write(1,{4{wdat[7:0]}});
		`STW_DEF158:	wb_write(1,{4{wdat[15:8]}});
		`STW_ACC70:		wb_write(1,{4{acc[7:0]}});
		`STW_ACC158:	wb_write(1,{4{acc[15:8]}});
		`STW_X70:		wb_write(1,{4{x[7:0]}});
		`STW_X158:		wb_write(1,{4{x[15:8]}});
		`STW_Y70:		wb_write(1,{4{y[7:0]}});
		`STW_Y158:		wb_write(1,{4{y[15:8]}});
		`STW_Z70:		wb_write(1,{4{8'h00}});
		`STW_Z158:		wb_write(1,{4{8'h00}});
`endif
		default:	wb_write(0,wdat);
		endcase
`ifdef SUPPORT_DCACHE
		radr <= wadr;		// Do a cache read to test the hit
`endif
		if (ir9==`PUSH)
			Rt <= 4'h0;
		state <= STORE2;
	end
	
// Terminal state for stores. Update the data cache if there was a cache hit.
// Clear any previously set lock status
STORE2:
	// On a retry operation, restore the stack pointer which may have been
	// modified, then go back to the decode state to pick up original 
	// addresses and data. This doesn't work for block move/store
	if (rty_i) begin
		wb_nack();
		isp <= oisp;
		state <= DECODE;
	end
	else if (ack_i) begin
		wdat <= dat_o;
		if (isMove|isSts) begin
			state <= MVN3;
			retstate <= MVN3;
		end
		else begin
			if (em) begin
				state <= BYTE_IFETCH;
				retstate <= BYTE_IFETCH;
			end
			else begin
				state <= IFETCH;
				retstate <= IFETCH;
			end
		end
		lock_o <= 1'b0;
		wb_nack();
		case(store_what)
		`STW_PC,`STW_PC2,`STW_PCHWI,`STW_OPC:
			if (isBrk|isBusErr) begin
				radr <= isp_dec;
				wadr <= isp_dec;
				isp <= isp_dec;
				store_what <= `STW_SR;
				state <= STORE1;
				retstate <= STORE1;
			end
		`STW_SR:
			if (isBrk|isBusErr) begin
				load_what <= `PC_310;
				state <= LOAD_MAC1;
				retstate <= LOAD_MAC1;
				radr <= vect[33:2];
				ttrig <= 1'b0;
				tf <= 1'b0;			// turn off trace mode
				im <= 1'b1;
				em <= 1'b0;			// make sure we process in native mode; we might have been called up during emulation mode
			end
		`STW_RFA:
			if (isPusha) begin
				if (ir[11:8]==4'hF) begin
					state <= IFETCH;
					retstate <= IFETCH;
				end
				else begin
					state <= STORE1;
					retstate <= STORE1;
					radr <= isp_dec;
					wadr <= isp_dec;
					isp <= isp_dec;
				end
				ir[11:8] <= ir[11:8] + 4'd1;
			end
`ifdef SUPPORT_816
		`STW_DEF70:
			begin
				lock_o <= 1'b1;
				wadr2LSB <= wadr2LSB + 2'b01;
				if (wadr2LSB==2'b11)
					wadr <= wadr + 32'd1;
				store_what <= `STW_DEF158;
				retstate <= STORE1;
				state <= STORE1;
			end
		`STW_ACC70:
			begin
				lock_o <= 1'b1;
				wadr2LSB <= wadr2LSB + 2'b01;
				if (wadr2LSB==2'b11)
					wadr <= wadr + 32'd1;
				store_what <= `STW_ACC158;
				retstate <= STORE1;
				state <= STORE1;
			end
		`STW_X70:
			begin
				lock_o <= 1'b1;
				wadr2LSB <= wadr2LSB + 2'b01;
				if (wadr2LSB==2'b11)
					wadr <= wadr + 32'd1;
				store_what <= `STW_X158;
				retstate <= STORE1;
				state <= STORE1;
			end
		`STW_Y70:
			begin
				lock_o <= 1'b1;
				wadr2LSB <= wadr2LSB + 2'b01;
				if (wadr2LSB==2'b11)
					wadr <= wadr + 32'd1;
				store_what <= `STW_Y158;
				retstate <= STORE1;
				state <= STORE1;
			end
		`STW_Z70:
			begin
				lock_o <= 1'b1;
				wadr2LSB <= wadr2LSB + 2'b01;
				if (wadr2LSB==2'b11)
					wadr <= wadr + 32'd1;
				store_what <= `STW_Z158;
				retstate <= STORE1;
				state <= STORE1;
			end
`endif
`ifdef SUPPORT_EM8
		`STW_PC3124:
			begin
				radr <= {spage[31:8],sp[7:2]};
				wadr <= {spage[31:8],sp[7:2]};
				radr2LSB <= sp[1:0];
				wadr2LSB <= sp[1:0];
				store_what <= `STW_PC2316;
				sp <= sp_dec;
				retstate <= STORE1;
				state <= STORE1;
			end
		`STW_PC2316:
			begin
				if (m816) begin
					radr <= {spage[31:24],8'h00,sp[15:2]};
					wadr <= {spage[31:24],8'h00,sp[15:2]};
					radr2LSB <= sp[1:0];
					wadr2LSB <= sp[1:0];
				end
				else begin
					radr <= {spage[31:16],8'h01,sp[7:2]};
					wadr <= {spage[31:16],8'h01,sp[7:2]};
					radr2LSB <= sp[1:0];
					wadr2LSB <= sp[1:0];
				end
				sp <= sp_dec;
				store_what <= `STW_PC158;
				retstate <= STORE1;
				state <= STORE1;
			end
		`STW_PC158:
			begin
				if (m816) begin
					radr <= {spage[31:24],8'h00,sp[15:2]};
					wadr <= {spage[31:24],8'h00,sp[15:2]};
					radr2LSB <= sp[1:0];
					wadr2LSB <= sp[1:0];
				end
				else begin
					radr <= {spage[31:16],8'h01,sp[7:2]};
					wadr <= {spage[31:16],8'h01,sp[7:2]};
					radr2LSB <= sp[1:0];
					wadr2LSB <= sp[1:0];
				end
				sp <= sp_dec;
				store_what <= `STW_PC70;
				retstate <= STORE1;
				state <= STORE1;
			end
		`STW_PC70:
			begin
				case({1'b0,ir[7:0]})
				`BRK: 	begin
						if (m816) begin
							radr <= {spage[31:24],8'h00,sp[15:2]};
							wadr <= {spage[31:24],8'h00,sp[15:2]};
							radr2LSB <= sp[1:0];
							wadr2LSB <= sp[1:0];
						end
						else begin
							radr <= {spage[31:16],8'h01,sp[7:2]};
							wadr <= {spage[31:16],8'h01,sp[7:2]};
							radr2LSB <= sp[1:0];
							wadr2LSB <= sp[1:0];
						end
						sp <= sp_dec;
						store_what <= `STW_SR70;
						retstate <= STORE1;
						state <= STORE1;
						end
				`JSR: 	begin
						pc[15:0] <= ir[23:8];
						end
				`JSL: 	begin
						pc <= ir[31:8];
						end
				`JSR_INDX:
						begin
						state <= LOAD_MAC1;
						retstate <= LOAD_MAC1;
						load_what <= `PC_70;
						radr <= absx_address[31:2];
						radr2LSB <= absx_address[1:0];
						end
				endcase
			end
		`STW_SR70:
			begin
				if (ir[7:0]==`BRK) begin
					load_what <= `PC_70;
					state <= LOAD_MAC1;
					retstate <= LOAD_MAC1;
					pc[31:16] <= abs8[31:16];
					radr <= vect[33:2];
					radr2LSB <= vect[1:0];
					im <= hwi;
				end
			end
`endif
		default:
			if (isJsrIndx) begin
				load_what <= `PC_310;
				state <= LOAD_MAC1;
				retstate <= LOAD_MAC1;
				radr <= ir[39:8] + x;
			end
			else if (isJsrInd) begin
				load_what <= `PC_310;
				state <= LOAD_MAC1;
				retstate <= LOAD_MAC1;
				radr <= ir[39:8];
			end
		endcase
`ifdef SUPPORT_DCACHE
		if (!dhit && write_allocate) begin
			state <= DCACHE1;
		end
`endif
	end
`ifdef SUPPORT_BERR
	else if (err_i) begin
		lock_o <= 1'b0;
		wb_nack();
		if (em | isStb)
			derr_address <= adr_o[31:0];
		else
			derr_address <= adr_o[33:2];
		intno <= 9'd508;
		state <= BUS_ERROR;
	end
`endif
