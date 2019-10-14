* embeddings n-grams.







***** UNFINISHED ******* ->  this is fine...




* there are a lot of 4-grams. 
	clear
	clear mata
	clear matrix 
	set maxvar 15000


local whereami = "tuk39938"
import delimited "/Users/`whereami'/Desktop/programs/emr_nlp/data.csv",   clear



* Redo import so that the periods in 2.5, 4.5 are kept.

* Split diet variable into individual words - total vocabular is quite small.
	split diet, p(" ") gen(word)
	gen patid = _n
	reshape long word, i(patid) j(wct)
	drop if word == ""
	
* merge embeddings 
	merge m:1 word using "/Users/`whereami'/Desktop/programs/emr_nlp/embed_subset.dta"
	drop if _merge == 2
	drop _merge

	
* here generate n-grams of embeddings, then split them later.
	* 2, 3, and 4 grams?  
	bysort patid (wct): gen nx1 = word
	bysort patid (wct): gen nx2 = word[_n+1]
	bysort patid (wct): gen nx3 = word[_n+2]
	bysort patid (wct): gen nx4 = word[_n+3]
	
	gen gram1 = nx1 
	gen gram2 = nx1 +" "+ nx2 
	gen gram3 = nx1 +" "+ nx2 +" "+ nx3
	gen gram4 = nx1 +" "+ nx2 +" "+ nx3+" "+nx4 
	
	drop nx1 nx2 nx3 nx4

* check lengths
	gen wc2 = wordcount(gram2)
	drop if wc2 != 2
	
	gen wc3 = wordcount(gram3)
	drop if wc3 != 3
	
	gen wc4 = wordcount(gram4)
	drop if wc4 != 4
	
	drop wc2 wc3 wc4
* keep list of unique ngrams
	gen wcc = 1

	foreach nm of numlist 1(1)4{
	preserve
		sort gram`nm'
		bysort gram`nm': egen word_count_`nm' = sum(wcc)
		duplicates drop gram`nm', force
		keep gram`nm'
		gen pr_reshap = gram`nm'
		split gram`nm', p(" ")
		gen gid = _n 
		drop gram`nm'
		reshape long gram`nm', i(gid) j(wctr)
		rename gram`nm' word
		merge m:1 word using "/Users/tuk39938/Desktop/programs/emr_nlp/embed_subset.dta"
		drop if _merge == 2
		drop _merge 
		replace embed1 = 0 if embed1 == .
		bysort gid: gen ngr_emb = sum(embed1)
			* note inconsistent treatment of missings here depending on whether other word has positive or negative embedding val.  
		bysort gid: egen ngram_embed`nm' = max(ngr_emb)
		drop word 
		duplicates drop gid, force
		drop ngr_emb embed* wctr gid
		rename pr_reshap gram`nm'
		save "/Users/`whereami'/Desktop/programs/emr_nlp/grams_embed_`nm'.dta", replace
	restore
	}
	drop wcc

	
* reload and merge word list back in
	* add word "indicators"
foreach grm of numlist 1(1)4{

	preserve

	merge m:1 gram`grm' using "/Users/`whereami'/Desktop/programs/emr_nlp/grams_`grm'.dta"
	drop _merge
	

	keep patid diet total_quantity gram`grm' embed1 
	bysort patid: gen pcct = _n 
	
	reshape wide gram`grm' embed1, i(patid) j(pcct)
	* all missing values set to 0. 
	ds embed1* 
	foreach v1 of varlist `r(varlist)' {
		replace `v1' = 0 if `v1' == .
	}

	 
* Train/Test Data - 70/30 split:
	set seed 41 
	gen rand_split = runiform()
	gen train = 0
	replace train = 1 if rand_split <= 0.7
log using "/Users/`whereami'/Desktop/programs/emr_nlp/results_ngrams_embed_log.log", append
	* run a lasso to select n-grams. 
	regress total_quantity embed* if train == 1


* post estimation
	predict pred_cons if train == 0, xb 

	
	* simplest sanity check - no negative predictions
	* replace pred_cons = max(0, pred_cons) if pred_cons != . 
	
		* summarize predicted values:
	di "PREDICTION:"
	summarize pred_cons if train == 0, d 
	
	di "ZEROS:"
	count if pred_cons == 0 & train == 0
	
	hist pred_cons if train == 0, title("Density of Predicted Daily Consumption in Oz") subtitle("`grm'gram Based Embeddings") graphregion(color(white))
	graph export "/Users/`whereami'/Desktop/programs/emr_nlp/embed_`grm'gram_preds.png", replace
	count if train == 0
	local test_ct = `r(N)'
	gen pred_error = (total_quantity - pred_cons)^2 if train == 0
	summarize pred_error if train == 0, d 
	local top = `r(p99)'
	hist pred_error if pred_error < `top', title("Density of Squared Error") subtitle("`grm'gram Based Embeddings") graphregion(color(white)) note("Below 99th %ile of Error Value")
	graph export "/Users/`whereami'/Desktop/programs/emr_nlp/embed_`grm'gram_prederr.png", replace

	*hist pred_error if pred_error < 1000
	egen mse = mean(pred_error) if train == 0
	replace mse = mse/`test_ct'
	summarize mse
	local mse_v = `r(mean)'
log close 	

	twoway (hist total_quantity if train == 1, color(green%30))  ( hist pred_cons if train == 0, color(red%30)), legend( label(1 "Actual") label(2 "Predicted")) graphregion(color(white)) note("(Actual values based on regular expression matching)") title("Predicted vs. 'Actual' Consumption Figures") subtitle("From a Linear Model x{&beta} where X is" "a collection of word embeddings for different `grm' grams" "Overall MSE - `mse_v' oz")
		graph export "/Users/`whereami'/Desktop/programs/emr_nlp/embed_`grm'gram_results.png", replace
	
restore
}
