/* 
 * VC allocator 
 * Allocates new virtual-channels for newly arrived packets.
 * 
 * "unrestricted" VC allocation (Peh/Dally style)
 * 
 * Takes place in two stages:
 * 
 *           stage 1. ** VC Selection **
 *                    Each waiting packet determines which VC it will request.
 *                    (v:1 arbitration). Can support VC alloc. mask here (from 
 *                    packet header or static or dynamic..)
 *                    
 * 
 *           stage 2. ** VC Allocation **
 *                    Access to each output VC is arbitrated (PV x PV:1 arbiters)
 * 
 */

module NL_vc_unrestricted_allocator (req,              // VC request
									 output_port,      // for which port?
									 vc_status,        // which VCs are free
									 vc_new,           // newly allocated VC id.
									 vc_new_valid,     // has new VC been allocated?
									 vc_allocated,     // change VC status from free to allocated?
									 vc_requested,     // which VCs were requested at each input VC?
									 //flit,           // head of each input VC buffer
									 flit_vcalloc_mask,// head of each input VC buffer
									 clk, rst_n);



	parameter np=5;
	parameter nv=2;
	
	//
	// selection policies
	//
	parameter vcselect_usepacketmask = 1;     // packet determines which VCs may be requested (not with bydestinationnode!)


	//-----   
	input [np-1:0][nv-1:0] req;
	input output_port_t output_port [np-1:0][nv-1:0];
	input [np-1:0][nv-1:0] vc_status;
	output [np-1:0][nv-1:0][nv-1:0] vc_new;
	output [np-1:0][nv-1:0] vc_new_valid;   
	output [np-1:0][nv-1:0] vc_allocated;  
	output [np-1:0][nv-1:0][nv-1:0] vc_requested;
	//input flit_t [np-1:0][nv-1:0] flit;
	input [np-1:0][nv-1:0][nv-1:0] flit_vcalloc_mask;
	input clk, rst_n;

	genvar i,j,k,l;

	logic [np-1:0][nv-1:0][nv-1:0] vc_mask;
	logic [np-1:0][nv-1:0][nv-1:0] stage1_request, stage1_grant;
	logic [np-1:0][nv-1:0][nv-1:0] selected_status;
	logic [np-1:0][nv-1:0][np-1:0][nv-1:0] stage2_requests, stage2_grants;
	logic [np-1:0][nv-1:0][nv-1:0][np-1:0] vc_new_;


	assign vc_requested=stage1_grant;
   
	generate
		for (i=0; i<np; i++) begin:foriports
			for (j=0; j<nv; j++) begin:forvcs

				//
				// Determine value of 'vc_mask'
				//
				// What VCs may be requested?
				//
				//    (a) all
				//    (b) use mask set in packet's control field
				//
				if (vcselect_usepacketmask) begin
					//`ifdef VCALLOC_USE_ALLOC_MASK
					//assign vc_mask[i][j] =  flit[i][j].control.vcalloc_mask;
					assign vc_mask[i][j] =  flit_vcalloc_mask[i][j];
				end else begin
					// packet may request any free VC
					assign vc_mask[i][j] = '1;
				end
	    
				//	    
				// Select VC status bits at output port of interest (determine which VCs are free to be allocated)
				//
				assign selected_status[i][j] = vc_status[oh2bin(output_port[i][j])];

				//
				// Requests for VC selection arbiter
				//
				// Narrows requests from all possible VCs that could be requested to 1
				//
				for (k=0; k<nv; k++) begin:forvcs2
					// Request is made if 
					// (1) Packet requires VC
					// (2) VC Mask bit is set
					// (3) VC is currently free, so it can be allocated
					//
					assign stage1_request[i][j][k] = req[i][j] && vc_mask[i][j][k] && selected_status[i][j][k];
				end

				//
				// first-stage of arbitration
				//
				// Arbiter state doesn't mean much here as requests on different clock cycles may be associated
				// with different output ports. vcselect_arbstateupdate determines if state is always or never
				// updated.
				//
				matrix_arb #(.size(nv), .multistage(1))
					 stage1arb
					 (.request(stage1_request[i][j]),
					  .grant(stage1_grant[i][j]),
					  .success((1==1)), 					  
					  .clk, .rst_n);

				//
				// second-stage of arbitration, determines who gets VC
				//
				for (k=0; k<np; k++) begin:fo
					for (l=0; l<nv; l++) begin:fv
						assign stage2_requests[k][l][i][j] = stage1_grant[i][j][l] && output_port[i][j][k];
					end
				end

				//
				// np*nv np*nv:1 tree arbiters
				//
				NL_tree_arbiter #(.multistage(0), .size(np*nv), .groupsize(nv)) 
						vcarb
							  (.request(stage2_requests[i][j]),
							   .grant(stage2_grants[i][j]),
							   .success((1==1)),
							   .clk, .rst_n);

				assign vc_allocated[i][j]=|(stage2_requests[i][j]);

				//
				// new VC IDs 
				//
				for (k=0; k<np; k++) begin:fo2
					for (l=0; l<nv; l++) begin:fv2
						// could get vc x from any one of the output ports
						assign vc_new_[i][j][l][k]=stage2_grants[k][l][i][j];
					end
				end
				
				for (l=0; l<nv; l++) begin:fv3
				   assign vc_new[i][j][l]=|vc_new_[i][j][l];
				end
				
				assign vc_new_valid[i][j]=|vc_new[i][j];
			end
		end
	endgenerate
   
endmodule // NW_vc_unrestricted_allocator
