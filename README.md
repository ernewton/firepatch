# firepatch

This is a patch for the firehose pipeline to improve the treatment of bad pixels. It includes a new bad pixel mask and an updated version of fire_badpixfix.pro. You should be able to replace the default files with these versions.

## More on bad pixels

Around line 527, the pipeline masks out pixels where the flux is less than -200. 
```
thismask = (ordermask EQ (31-qq)) AND waveimg GT 0.0 AND sciimg GT -200.
```

These pixels are not accounted for by either my pixel mask or the original one. But, this creates small dips in the spectrum where there is missing flux. Instead, I expect it is better to treat them the same way as bad pixels. To this end, you can add the following around line 373.

```
ernmask = sciimg*0. + 1.
ernmask[WHERE(sciimg LE -200)] = 0.
cleaned_sciimg = fire_badpixfix(sciimg, msk=ernmask)
cleaned_skyimage = fire_badpixfix(skyimage, msk=ernmask)
  
sciimg = cleaned_sciimg
skyimage = cleaned_skyimage
```

## A small change to the spextool telluric correction

I found that the IDL routine c_correlate, used by Spextool to shift the observed A star to match Vega, was being pulled to 0 and was not quite smooth. I have no idea what the issue is, but using the routine cross_correlate instead works. To do this, replace lines 129 to 132:
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