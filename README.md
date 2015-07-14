# firepatch

This is a patch for the firehose pipeline to improve the treatment of bad pixels. The linear interpolation as implemented by the pipeline cannot effectively interpolate over consecutive bad pixels, and the flux assigned to those pixels is artificially low (sometimes 0, if the bad pixels form a plus shape). This becomes an issue if pixels that would otherwise contain a significant amount of flux are bad, and results in dips in a boxcar-extracted spectrum. 

This patch includes a new bad pixel mask created from a Fowler-16 dark image using a 5-sigma clip, and an updated version of fire_badpixfix.pro. You should be able to replace the default files with these versions.

There are several other changes that I made that you may wish to incorporate as well, which are detailed below. Implementing them will require the small changes to the IDL scripts that I describe below. They may not be necessary for you, as my objects are particularly bright.


### More on bad pixels

Extract/fire_echextobj.pro performs some extra pixel masking. At line 514, the pipeline masks out pixels where the flux is less than -200. 
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

I found that the IDL routine c_correlate, used by Spextool to shift the observed A star to match Vega, was being pulled to 0 and was not quite smooth. I have no idea what the issue is, but using the routine cross_correlate instead works. To do this, in Spextool/pro/vegacorr.pro replace lines 129-132:
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


