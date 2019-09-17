* Gen indicator matrix...



local whereami = "tuk39938"
import delimited "/Users/`whereami'/Desktop/programs/emr_nlp/data.csv",   clear



* Redo import so that the periods in 2.5, 4.5 are kept.

* Split diet variable into individual words - total vocabular is quite small.
	split diet, p(" ") gen(word)
	gen patid = _n
	reshape long word, i(patid) j(wct)

* keep list of unique words
	drop if word == ""
	sort word
	duplicates drop word, force
	keep word
	* "indicator" for each word
	gen has = _n 
	save "/Users/`whereami'/Desktop/programs/emr_nlp/wordlist.dta", replace

* reload and merge word list back in
	import delimited "/Users/`whereami'/Desktop/programs/emr_nlp/data.csv",   clear
	* resplit 
	split diet, p(" ") gen(word)
	gen patid = _n
	reshape long word, i(patid) j(wct)
	drop if word == ""
	* add word "indicators"
	merge m:1 word using "/Users/`whereami'/Desktop/programs/emr_nlp/wordlist.dta"
	drop _merge
	
* generate collection of indicator variables for each word 

	levelsof has, local(numwords)
	foreach nm1 of local numwords{
		gen v`nm1' = 0
		replace v`nm1' = 1 if has == `nm1'
	}
	collapse (sum) v* (first) total_quantity diet , by(patid)


* Train/Test Data - 70/30 split:
	set seed 41 
	gen rand_split = runiform()
	gen train = 0
	replace train = 1 if rand_split <= 0.7

* Linear Model for Prediction
	regress total_quantity v* if train == 1

* Predict
	predict pred_cons if train == 0, xb 
	count if train == 0
	local test_ct = `r(N)'
	gen pred_error = (total_quantity - pred_cons)^2 if train == 0
	summarize pred_error, d 
	local top = `r(p99)'
	hist pred_error if pred_error < `top'
	egen mse = mean(pred_error) if train == 0
	replace mse = mse/`test_ct'
	summarize mse
/*
		Variable |        Obs        Mean    Std. Dev.       Min        Max
	-------------+---------------------------------------------------------
			 mse |      1,514    1.055129           0   1.055129   1.055129
*/
