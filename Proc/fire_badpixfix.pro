
; Performs bilinear interpolation to fix bad pixels from a given mask.
; If no mask is provided, a default archived mask is used, and
; the mask is returned in the mask keyword

function fire_badpixfix, rawimg, msk=mask
; renamed msk -> mask because original program in error

  if (not keyword_set(mask) or n_elements(mask) LT 2) then begin
     mask = transpose(reverse(xmrdfits(strtrim(getenv("FIRE_DIR"),2)+"/Calib/fire_badpix.fits.gz")))
  endif
  
  badpix = where(mask EQ 0, nmsk)
  gdpix = where(mask EQ 1, ngd)
  cleaned = rawimg * mask

  if (nmsk GT 0) then begin

     if (0) then begin ; original method, fails for plus-shaped bad pixels
        interp_img  = (shift(cleaned,  1,  0) + $
                      shift(cleaned, -1,  0) + $
                      shift(cleaned,  0, -1) + $
                      shift(cleaned,  0,  1)) / 4.0
     endif else begin

         ; use nan-resistant means to interpolate and iterate
         ; in order to avoid issues with consecutive bad pixels
         
         ; temp will contain the iteratively improved cleaned image
         temp = rawimg
         temp[WHERE(mask EQ 0)] = 0./0.
         bp = WHERE(finite(temp) EQ 0, count)
         
         while count GT 0 do begin
            arr    = [[[shift(temp,  1,  0)]], $
                      [[shift(temp, -1,  0)]], $
                      [[shift(temp,  0, -1)]], $
                      [[shift(temp,  0,  1)]]]
            ; fix points that still need to be fixed
            bp = WHERE(finite(temp) EQ 0, count)
            interp_img = mean(arr, dimension=3, /nan)
            if count GT 0 then temp[bp] = interp_img[bp]
         endwhile
     
     endelse
     
     cleaned[badpix] = interp_img[badpix]

  endif

  return, cleaned

end



function badpixnew

  dark = xmrdfits(strtrim(getenv("FIRE_DIR"),2)+"/Calib/fowler16dark.fits")
  s = stddev(dark[WHERE(abs(dark) LT 8.8)]) ; about 5 sigma clip
  
  mask = dark * 0.
  mask[WHERE(ABS(dark) LT 5.*s)] = 1
  
  mwrfits, mask, strtrim(getenv("FIRE_DIR"),2)+"/Calib/fire_badpix_new.fits.gz", /create
 
  return, mask
  
end