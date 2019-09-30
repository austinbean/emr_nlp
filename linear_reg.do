* Gen indicator matrix...



local whereami = "tuk39938"
import delimited "/Users/`whereami'/Desktop/programs/emr_nlp/data.csv",   clear
/*
There is a lot more intelligent processing which can be done here - especially
stripping out nonsense or irrelevant words.  

*/


* Redo import so that the periods in 2.5, 4.5 are kept.

* Split diet variable into individual words - total vocabular is quite small.
	split diet, p(" ") gen(word)
	gen patid = _n
	reshape long word, i(patid) j(wct)

* keep list of unique words
	drop if word == ""
	sort word
	gen wcc = 1
	bysort word: egen word_count = sum(wcc)
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
	* negative predictions make no sense.  
	replace pred_cons = max(0, pred_cons)
	hist pred_cons if train == 0, title("Density of Daily Consumption in Oz") graphregion(color(white))
	twoway (hist total_quantity if train == 1, color(green%30))  ( hist pred_cons if train == 0, color(red%30)), legend( label(1 "Actual") label(2 "Predicted")) graphregion(color(white)) note("(Actual values based on regular expression matching)") title("Predicted vs. 'Actual' Consumption Figures") subtitle("From a simple linear model x{&beta} where X is" "a collection of indicators for the presence  of a single word" "Overall MSE - 0.14 oz")
	graph export "/Users/`whereami'/Desktop/programs/emr_nlp/linear_results.png", replace
	count if train == 0
	local test_ct = `r(N)'
	gen pred_error = (total_quantity - pred_cons)^2 if train == 0
	summarize pred_error, d 
	local top = `r(p99)'
	hist pred_error if pred_error < `top'
	hist pred_error if pred_error < 1000
	egen mse = mean(pred_error) if train == 0
	replace mse = mse/`test_ct'
	summarize mse
/*

    Variable |        Obs        Mean    Std. Dev.       Min        Max
-------------+---------------------------------------------------------
         mse |      1,678    .1478308           0   .1478308   .1478308


*/
