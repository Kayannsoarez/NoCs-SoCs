/*
 * Tree Matrix Arbiter
 * 
 * - 'multistage' parameter - see description in matrix_arbiter.v
 * 
 * The tree arbiter splits the request vector into groups, performing arbitration
 * simultaneously within groups and between groups. Note this has implications 
 * for fairness.
 * 
 * Only builds one level of a tree
 * 
 */

module NL_tree_arbiter (request, grant, success, clk, rst_n);

   parameter multistage=0;
   parameter size=20;
   parameter groupsize=4;
   parameter numgroups=size/groupsize;
   
   input [size-1:0] request;
   output [size-1:0] grant;
   input 	     success;
   input 	     clk, rst_n;
   
   logic [size-1:0] intra_group_grant;
   logic [numgroups-1:0] group_grant, any_group_request;
   logic [numgroups-1:0] current_group_success;//, last_group_success;
   logic [numgroups-1:0] group_success;

      
   genvar i;

   generate

   for (i=0; i<numgroups; i=i+1) begin:arbiters

     //
     // group_arbs need to be multistage=1, as group may not get granted
     //
     matrix_arb #(.size(groupsize),
		  .multistage(1)) arb
	   (.request(request[(i+1)*groupsize-1:i*groupsize]),
	    .grant(intra_group_grant[(i+1)*groupsize-1:i*groupsize]),
	    .success(group_success[i] & success),
	    .clk, .rst_n);

			   
      assign any_group_request[i] = |request[(i+1)*groupsize-1:i*groupsize];

      assign grant[(i+1)*groupsize-1:i*groupsize]=
      	     intra_group_grant[(i+1)*groupsize-1:i*groupsize] & {groupsize{group_grant[i]}};

      assign current_group_success[i]= group_grant[i];
      
   end
   
      assign group_success=current_group_success;
   
   endgenerate
   
   
   matrix_arb #(.size(numgroups),
		.multistage(multistage)) group_arb 
     (.request(any_group_request),
      .grant(group_grant),
      .success(success),
      .clk, .rst_n);

endmodule // tree_arbiter



/* -------------------------------------------------------------------------------
 * (C)2007 Robert Mullins
 * Computer Architecture Group, Computer Laboratory
 * University of Cambridge, UK.
 * -------------------------------------------------------------------------------
 *
 * Matrix Arbiter
 * 
 * See Dally/Towles (p.359) for implementation details and full description
 * 
 * Multistage Options
 * ==================
 * 
 * [multistage=0] Arbiter state is updated whenever a request is granted.
 * 
 * [multistage=1] This arbiter is meant for situations where the initial 
 * request must progress through multiple stages of arbitration. An 
 * additional input to the arbiter (success) ensures that the state of 
 * the arbiter is only updated if the request is finally granted (at the 
 * last stage of arbitration).
 * 
 * || This assumes 'success' is produced before the end of the current clock 
 * || cycle.
 * 
 * [multistage=2] Used in situations where multistage=1 would be, but when
 * 'success' is not available until the next clock cycle.
 * 
 */


module comb_matrix_arb_next_state (state, grant, new_state);
   parameter size=4;
   
   input [size*size-1:0] state;
   input [size-1:0] grant;
   output [size*size-1:0] new_state;

   genvar i,j;
   
   generate
   for (i=0; i<size; i=i+1) begin:ol2
      for (j=0; j<size; j=j+1) begin:il2
         assign new_state[j*size+i]= (state[j*size+i]&&!grant[j])||(grant[i]);
      end
   end
   endgenerate

endmodule // comb_matrix_arb_next_state



module matrix_arb (request, grant, success, clk, rst_n);
   
   parameter size= 4;
   parameter multistage = 0;
   //parameter grant_hold = 0;
   
   input [size-1:0] request;
   output [size-1:0] grant;
   input success;
   input clk, rst_n; 

   genvar i,j;

   logic [size-1:0] req;
   //logic [size-1:0] newgrant;
   logic [size*size-1:0] /*next_state,*/ current_state;
   logic [size-1:0] pri [size-1:0];
   logic [size*size-1:0] new_state;
   logic [size*size-1:0] state;

   //logic  update;

   //genvar r;

   //integer k;

   assign req=request;
   
   // ##########################################
   // Generate grants
   // ##########################################
   generate
   for (i=0; i<size; i=i+1) begin:ol1
      // generate grant i
      for (j=0; j<size; j=j+1) begin:il1
         if (j==i) 
           // request i wins if requesting and....
           assign pri[i][j]=req[i];
         else 
           // ....no other request with higher priority
           if (j>i)
             // j beats i
             assign pri[i][j]=!(req[j]&&state[j*size+i]);
           else
             // !(i beats j)
             assign pri[i][j]=!(req[j]&&!state[i*size+j]);
      end

      assign grant[i]=&pri[i];
      
   end
   endgenerate

   generate

      assign state = current_state;

   endgenerate
   
   //
   // calculate next matrix state based on current requests and grants
   //
   comb_matrix_arb_next_state #(size) calc_next (.*);
   
   always@(posedge clk) begin
     if (!rst_n) begin
        current_state<='1; //-1;
		//next_state<='1; //-1; 
     end else begin

	   // ************************************
	   // Multistage Arbiter (multistage==1)
	   // ************************************
	   // check request was ultimately successful before updating arbiter state
	   // we know about success before the next clock cycle.
	   if ((multistage==1)&!success) begin
	      // request was not ultimately successful, don't update priorities
	   end else begin

	      // **********************************
	      // Basic Arbiter (multistage==0)
	      // **********************************
	      // Update state whenever at least one request has been made
              if (|req) begin
					current_state<=new_state;
              end
	   end
       end
   end
                                                  
endmodule
