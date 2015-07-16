# firepatch

This is a patch for the firehose pipeline to improve the treatment of bad pixels for boxcar extraction. The linear interpolation as implemented by the pipeline cannot effectively interpolate over consecutive bad pixels, and the flux assigned to those pixels is artificially low (sometimes 0, if the bad pixels form a plus shape). This becomes an issue if pixels that would otherwise contain a significant amount of flux are bad, and results in dips in a boxcar-extracted spectrum. 

This patch includes a new bad pixel mask created from a Fowler-16 dark image using a 5-sigma clip, with additional bad pixels masked from a pair of blank images, and an updated version of fire_badpixfix.pro. The new routine is the same simple bilinear interpolation, but ignores bad pixels and iterates to fill in all gaps. You should be able to replace the default files with these versions.

There are several other changes that I made that you may wish to incorporate as well, which are detailed below. Implementing them will require the small changes to the IDL scripts that I describe. They may not be necessary for you, as my objects are particularly bright. 

If you choose to implement any of these changes, you might consider inspecting at the final images to see if they look as you expect.

[![DOI](https://zenodo.org/badge/doi/10.5281/zenodo.20541.svg)](http://dx.doi.org/10.5281/zenodo.20541)

### Caveats

The data that I used to create the bad pixel masks is from 2011, and the data on which I have tested the new masks is from 2011-2012. 

Bilinear interpolation is not a very sophisticated method, and will not adequately account for the case where the bad pixel is brighter than the surrounding pixels (as will be the case if the bad pixel falls at the peak of your line profile). Fixing this will require a higher-order correction. If you have exposures at two nod positions, you can reject data in the final spectrum where the disagreement between the two is significant (combining the exposures will not fix the issue as half your spectra will be affected). This could also be accomplished using the Spextool xcombspec built-in routines (check out https://github.com/jgagneastro/FireHose_v2 for a return to the full functionality), and the fire combination routine succesfully handles some of these. Alternatively, if you used a random dithering pattern, combining the exposures should largely account for bad pixels.


### More on bad pixels

The routine Extract/fire_echextobj.pro performs some extra pixel masking. At line 514, the pipeline masks out pixels where the flux is less than -200. 
```
thismask = (ordermask EQ (31-qq)) AND waveimg GT 0.0 AND sciimg GT -200.
```

These pixels are not accounted for by either my pixel mask or the original one. But, this masking creates small dips in the spectrum where there is missing flux. It is presumably better to treat them the same way as bad pixels. To this end, you can add the following at line 365/366.

```
ernmask = sciimg*0. + 1.
ernmask[WHERE(sciimg LE -200)] = 0.
cleaned_sciimg = fire_badpixfix(sciimg, msk=ernmask)
cleaned_skyimage = fire_badpixfix(skyimage, msk=ernmask)
  
sciimg = cleaned_sciimg
skyimage = cleaned_skyimage
```

The routine fire_proc may do additional masking; it is built in to the divideflat routine that is called at line 107. Pixels with values less than minval are set to 0; minval is set at line 58. The default is 0.5, which resulted in at least one zero-d out pixel in my data. Looking at the distribution of flatfield values for my flats, 0.3 made sense as a lower limit.


### Masking the object for sky subtraction

The object is masked by the xidl routine long_objfind (xidl/Spec/Longslit/pro) which masks out a portion of the spectrum surrounding the object. It only masks out a box the size of the FWHM, and I found that there was a lot of object light left over in my sky image, primarily resulting in a deformation of the continuum (it was not too significant for me). This can be adjusted by inflating the size of the mask at lines 609-610, e.g. for a 5-sigma clip:
```
inflate = 5.D*2.3
left_ind  = objstruct.xpos - $
     replicate(median_fwhm*inflate, nobj) ## replicate(1.0D, ny)/2.0D
right_ind = objstruct.xpos + $
     replicate(median_fwhm*inflate, nobj) ## replicate(1.0D, ny)/2.0D
```

### Cross correlation in the Spextool telluric correction

I found that the IDL routine c_correlate, used by Spextool to shift the observed A star to match Vega, was being pulled to 0. I have no idea what the issue is, but using the routine cross_correlate instead works. To do this, in Spextool/pro/vegacorr.pro replace lines 129-132:
```
lag    = indgen(num)-(num/2)
result = c_correlate(fxvega,fxdata,lag)
pfit   = mpfitpeak(lag,result,pcoefs,/GAUSSIAN,NTERMS=3)
lshift = pcoefs(1)
```
with  
````
cross_correlate, fxdata, fxvega, lshift, result, width=100
```

### Edge masking in order combination

The edges of the orders may not be well-behaved (this may be the result of the new masking procedure). The FIRE pipeline weights the overlapping order edges with a linear slope, but does not necessarily make the weights go to zero at the boundaries. Add the following to Flux/fire_1dspec at line 157 (within the for loop) to mask the first 5 non-zero pixels.
```
gd = where(spec.fx[*,use[i]] GT 0)
edge_weight[gd[0:4],i] = 0
edge_weight[gd[-5:-1],i] = 0
```
     