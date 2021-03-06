;
; **********************************************************************
;
; Load files.
;
; **********************************************************************
;
loadscript(lib_location + "pause.ncl")
loadscript(lib_location + "constants.ncl")
loadscript(lib_location + "strcmp_exact.ncl")
loadscript(lib_location + "strpad.ncl")
loadscript(lib_location + "repeat_str.ncl")
loadscript(lib_location + "convert_sphr_coords_to_lambert_cnfrml.ncl")
loadscript(lib_location + "convert_lambert_cnfrml_coords_to_sphr.ncl")

undef("calc_wrtcmp_grid_params_lambert_cnfrml")

function calc_wrtcmp_grid_params_lambert_cnfrml( \
         model_config_tmpl_fp:string, \
         lon_ctr_native:snumeric, lat_ctr_native:snumeric, \
         lon_tile_corners_face_midpts_native[8]:snumeric, \
         lat_tile_corners_face_midpts_native[8]:snumeric, \
         dx_native:snumeric, dy_native:snumeric, \
         angle_units:string)

local lon_ctr, lat_ctr, lat1, lat2, \
      x_SW_native, y_SW_native, \
      num_gap_cells, \
      dx, x_SW, x_NE, Lx, Lx_ovr_dx, nx, frac_x, x_increment, \
      dy, y_SW, y_NE, Ly, Ly_ovr_dy, ny, frac_y, y_increment, \
      sphr_coords, lonctr_ll_cell, latctr_ll_cell, \
      param_names, num_params, param_names_and_vals, trailing_comments, \ 
      np, param_name, param_value, param_value_str, \
      regex_search, regex_print, sed_cmd, \
      fmt_str, msg, \
      str_lens, str_len_max, num_delimit_spaces, delimit_spaces, \
      lines_final, regex_replace, sed_output, \
      out

begin
;
; **********************************************************************
;
; If not already defined, define the string (separator_line) that serves
; as a separator line between different sections of printout.
;
; **********************************************************************
;
  if (.not. isvar("separator_line")) then
    separator_line := repeat_str("=", 72)
  end if
;
; **********************************************************************
;
; Set the coordinates of the center of the write-component output grid
; to be equal to those of the native grid.  Also, set the latitudes de-
; fining the two standard parallels of the Lambert conformal projection
; used by the output grid to the latitude of the output grid center.
;
; **********************************************************************
;
  lon_ctr = lon_ctr_native
  lat_ctr = lat_ctr_native
  lat1 = lat_ctr
  lat2 = lat_ctr
;
; **********************************************************************
;
; Calculate the Lambert coordinates of the southwest corner of the na-
; tive grid from its spherical coordinates.
;
; **********************************************************************
;
  lambert_coords \
  := convert_sphr_coords_to_lambert_cnfrml( \
     lon_ctr, lat_ctr, lat1, lat2, rad_Earth, angle_units, \
     lon_tile_corners_face_midpts_native, \
     lat_tile_corners_face_midpts_native)
  x_tile_corners_face_midpts_native = lambert_coords@x
  y_tile_corners_face_midpts_native = lambert_coords@y

  i = 0
  x_SW_native = x_tile_corners_face_midpts_native(i)
  y_SW_native = y_tile_corners_face_midpts_native(i)

  i = i + 1
  x_S_native = x_tile_corners_face_midpts_native(i)
  y_S_native = y_tile_corners_face_midpts_native(i)

  i = i + 1
  x_SE_native = x_tile_corners_face_midpts_native(i)
  y_SE_native = y_tile_corners_face_midpts_native(i)

  i = i + 1
  x_E_native = x_tile_corners_face_midpts_native(i)
  y_E_native = y_tile_corners_face_midpts_native(i)
  
  i = i + 1
  x_NE_native = x_tile_corners_face_midpts_native(i)
  y_NE_native = y_tile_corners_face_midpts_native(i)

  i = i + 1
  x_N_native = x_tile_corners_face_midpts_native(i)
  y_N_native = y_tile_corners_face_midpts_native(i)

  i = i + 1
  x_NW_native = x_tile_corners_face_midpts_native(i)
  y_NW_native = y_tile_corners_face_midpts_native(i)

  i = i + 1
  x_W_native = x_tile_corners_face_midpts_native(i)
  y_W_native = y_tile_corners_face_midpts_native(i)
;
; **********************************************************************
;
;
;
; **********************************************************************
;
  dx = dx_native 
  dy = dy_native 
  num_margin_cells = 1
;  num_margin_cells = 5
;  num_margin_cells = 100
;
; **********************************************************************
;
; Reduce the extent of the write-component grid in both the positive and
; negative x directions until the latitude of the center of the west 
; face of the write-component grid is greater than that of the native 
; grid, and the latitude of the center of the east face of the write-
; component grid is less than that of the native grid (i.e. the write-
; component grid lies within the native grid in the x direction).  Then,
; as an extra safety measure, reduce each of these extents by a further
; nc_reduce_extra_max cells of size dx.
;
; **********************************************************************
;
  x_W_native_max = max((/x_SW_native, x_W_native, x_NW_native/))
  x_E_native_min = min((/x_SE_native, x_E_native, x_NE_native/))

  x_W = x_W_native_max + num_margin_cells*dx
  x_E = x_E_native_min - num_margin_cells*dx

  Lx = x_E - x_W
  Lx_ovr_dx = Lx/dx
  nx = tointeger(Lx_ovr_dx)
  frac_x = Lx_ovr_dx - nx
  x_adj = (0.5d+0*frac_x)*dx
  x_W = x_W + x_adj
  x_E = x_E - x_adj
;
; **********************************************************************
;
;
;
; **********************************************************************
;
  y_S_native_max = max((/y_SW_native, y_S_native, y_SE_native/))
  y_N_native_min = min((/y_NW_native, y_N_native, y_NE_native/))

  y_S = y_S_native_max + num_margin_cells*dy
  y_N = y_N_native_min - num_margin_cells*dy

; The following forces the write-component domain in Lambert conformal
; space (i.e. the xy-plane) to be symmetric (about (x,y)=(0,0)) in the y 
; direction.  Can't remember why I wanted to enforece this...
  y_S = -min(abs((/y_S, y_N/)))
  y_N = -y_S

  Ly = y_N - y_S
  Ly_ovr_dy = Ly/dy
  ny = tointeger(Ly_ovr_dy)
  frac_y = Ly_ovr_dy - ny
  y_adj = (0.5d+0*frac_y)*dy
  y_S = y_S + y_adj
  y_N = y_N - y_adj
;
; **********************************************************************
;
; Calculate the spherical coordinates of the southwest corner of the 
; native grid from its Lambert coordinates.  
;
; Note that the coordinates that the write-component takes as input are 
; those of the center of the grid cell at the lower-left corner of the 
; grid.  However, the Lambert coordinates (x_W, y_S) caluclated above 
; are those of the lower-left vertex (not center) of that cell.  Thus, 
; we first add half a grid distance in the x and y directions to the 
; Lambert coordinates of the vertex to obtain the Lambert coordinates of 
; the cell center.  We then convert the result to spherical coordinates.
;
; **********************************************************************
;
  xctr_ll_cell = x_W + 0.5*dx
  yctr_ll_cell = y_S + 0.5*dy

  sphr_coords \
  := convert_lambert_cnfrml_coords_to_sphr( \
     lon_ctr, lat_ctr, lat1, lat2, rad_Earth, angle_units, \
     xctr_ll_cell, yctr_ll_cell)
  lonctr_ll_cell = sphr_coords@lon
  latctr_ll_cell = sphr_coords@lat
;
; **********************************************************************
;
; Create a string array containing the names of the Lambert conformal
; output grid parameters that appear in the NEMS model_configure file.
;
; **********************************************************************
;
  param_names = (/ \
    "output_grid", \
    "cen_lon", \
    "cen_lat", \
    "stdlat1", \
    "stdlat2", \
    "nx", \
    "ny", \
    "lon1", \
    "lat1", \
    "dx", \
    "dy" /)
;
; **********************************************************************
;
; Get the number of Lambert conformal output grid parameters that need 
; to be se tin the NEMS model_configure file.  Then initialize string 
; arrays needed in setting these parameters.
;
; **********************************************************************
;
  num_params = dimsizes(param_names)
  param_names_and_vals := new(num_params, "string")
  trailing_comments := new(num_params, "string")
;
; **********************************************************************
;
;
;
; **********************************************************************
;
  np = 0
  param_name = param_names(np)
  param_value := char_sq + "lambert_conformal" + char_sq
  param_value_str := tostring(param_value)

  regex_search = "^(\s*" + param_name + ":\s+)('\{\{\s*" + param_name + "\s*\}\}')(\s*)(.*)"

  regex_print = "\1" + param_value_str
  sed_cmd = "sed -n -r -e " + char_dq + "s|" + regex_search + "|" \
          + regex_print + "|p" + char_dq + " " + model_config_tmpl_fp
  param_names_and_vals(np) = systemfunc(sed_cmd)

  regex_print = "\4"
  sed_cmd = "sed -n -r -e " + char_dq + "s|" + regex_search + "|" \
          + regex_print + "|p" + char_dq + " " + model_config_tmpl_fp
  trailing_comments(np) = systemfunc(sed_cmd)
;
; **********************************************************************
;
;
;
; **********************************************************************
;
  do np=1, num_params-1

    param_name := param_names(np)

    if (strcmp_exact(param_name, "cen_lon")) then
      param_value := lon_ctr
      fmt_str = "%16.8f"
    else if (strcmp_exact(param_name, "cen_lat")) then
      param_value := lat_ctr
      fmt_str = "%16.8f"
    else if (strcmp_exact(param_name, "stdlat1")) then
      param_value := lat1
      fmt_str = "%16.8f"
    else if (strcmp_exact(param_name, "stdlat2")) then
      param_value := lat2
      fmt_str = "%16.8f"
    else if (strcmp_exact(param_name, "nx")) then
      param_value := nx
      fmt_str = "%10.0f"
    else if (strcmp_exact(param_name, "ny")) then
      param_value := ny
      fmt_str = "%10.0f"
    else if (strcmp_exact(param_name, "lon1")) then
      param_value := lonctr_ll_cell
      fmt_str = "%16.8f"
    else if (strcmp_exact(param_name, "lat1")) then
      param_value := latctr_ll_cell
      fmt_str = "%16.8f"
    else if (strcmp_exact(param_name, "dx")) then
      param_value := dx
      fmt_str = "%16.8f"
    else if (strcmp_exact(param_name, "dy")) then
      param_value := dy
      fmt_str = "%16.8f"
    else

      msg := char_nl + \
"Unknown parameter name specified for given output_coord_sys:" + char_nl + \
"  output_coord_sys = " + char_dq + output_coord_sys + char_dq + char_nl + \
"  param_name = " + char_dq + param_name + char_dq + char_nl + \
"Stopping."
      print("" + msg)
      exit

    end if
    end if
    end if
    end if
    end if
    end if
    end if
    end if
    end if
    end if
;
; Generate a string containing the parameter value and formatted as spe-
; cified by fmt_str.  Then strip any leading and trailing whitespace 
; from it.
;
    param_value_str := sprintf(fmt_str, param_value)
    param_value_str := str_strip(param_value_str)
;
; Set the regular expression to search for.
;
    regex_search = "^(\s*" + param_name + ":\s+)(\{\{\s*" + param_name + "\s*\}\})(\s*)(.*)"
;
; Get the parameter name and value without the trailing comment (if any).
;
    regex_print = "\1" + param_value_str
    sed_cmd = "sed -n -r -e " + char_dq + "s|" + regex_search + "|" \
            + regex_print + "|p" + char_dq + " " + model_config_tmpl_fp
    tmp := systemfunc(sed_cmd)
    param_names_and_vals(np) = tmp(0)
;
; Get the trailing name and comment.
;
    regex_print = "\4"
    sed_cmd = "sed -n -r -e " + char_dq + "s|" + regex_search + "|" \
            + regex_print + "|p" + char_dq + " " + model_config_tmpl_fp
    tmp := systemfunc(sed_cmd)
    trailing_comments(np) = tmp(0)

  end do
;
; **********************************************************************
;
; Generate a string array containing each line in the model_configure
; file that specifies a parameter describing the write-component output
; grid.  Each such line will contain the parameter name, value, and an
; trailing comment, with the trailing comments aligned for readability.
;
; **********************************************************************
;
  lines_final := strpad(param_names_and_vals, " ", "right")
  lines_final := lines_final + "  " + trailing_comments
;
; **********************************************************************
;
; Print out the write-component parameter values calculated above.
;
; **********************************************************************
;
  msg := char_nl + \
"Write-component parameters corresponding to this native grid are:" + char_nl
  print("" + msg)
  print("" + lines_final)
;
; **********************************************************************
;
; Loop through the set of parameters and find the line in the template
; file where each is set.  Then replace that line with the corresponding
; line generated above containing the parameter name, its value, and the
; optional aligned comment.
;
; **********************************************************************
;
  do np=0, num_params-1
    param_name = param_names(np)
    regex_search = "^(\s*" + param_name + ":\s+)(<" + param_name + ">)(\s*)(.*)"
    regex_replace = lines_final(np)
    sed_cmd = "sed -i -r -e " + char_dq + "s|" + regex_search + "|" \
            + regex_replace + "|" + char_dq + " " + wrtcmp_config_fn
    sed_output = systemfunc(sed_cmd)
  end do
;
; **********************************************************************
;
;
;
; **********************************************************************
;
  out = True 
  return(out)

end

