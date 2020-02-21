/* -------------------------------------------------------------------------------
 * @file nalu_package.vhd
 * @brief Package with Defines definitions, Typedef definitions and Misc. functions packages for NaluNoC
 * @authors Alexandre Coelho, alexandre.coelho@imag.fr
 * @date 01/02/2017
 * @copyright TIMA.
*/

/* -------------------------------------------------------------------------------
 * Misc. functions package
 * 
 *   - abs (x)   - absolute function
 *   - max (x,y) - returns larger of x and y
 *   - min (x,y) - returns smaller of x and y
 */

function automatic integer abs (input integer x);
   begin
      if (x>=0) return (x); else return (-x);
   end
endfunction
 
function automatic integer min (input integer x, input integer y);
   begin
      min = (x<y) ? x : y;
   end
endfunction

function automatic integer max (input integer x, input integer y);
   begin
      max = (x>y) ? x : y;
   end
endfunction

function automatic x_coord_t set_x_cur (input integer x);
   begin
      set_x_cur = x;
   end
endfunction

function automatic y_coord_t set_y_cur (input integer y);
   begin
      set_y_cur = y;
   end
endfunction

