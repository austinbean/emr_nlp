* use top two embeddings.


clear 
local whereami = "austinbean"

use "/Users/`whereami'/Desktop/programs/emr_nlp/diet_embed.dta", replace

keep word embed1 embed2

save "/Users/`whereami'/Desktop/programs/emr_nlp/embed_2subset.dta", replace


import delimited "/Users/`whereami'/Desktop/programs/emr_nlp/data.csv",   clear


* Split diet variable into individual words - total vocabulary is quite small.
	split diet, p(" ") gen(word)
	gen patid = _n
	reshape long word, i(patid) j(wct)
	drop if word == ""

* merge embeddings

	merge m:1 word using "/Users/`whereami'/Desktop/programs/emr_nlp/embed_2subset.dta"
	drop if _merge == 2
	drop _merge

		
* reshape wide, replace 0, take sum.
	sort patid wct
	reshape wide word embed1 embed2 , i(patid) j(wct)

		
* replace as zeros, take row sum

	foreach num of numlist 1(1)2{
		foreach j of numlist 1(1)22{
			replace embed`num'`j' = 0 if embed`num'`j' == .
		}
	}
	
	egen total_embed = rowtotal(embed*)

	
		
* Try a simple linear reg...

	set seed 41 
	gen rand_split = runiform()
	gen train = 0
	replace train = 1 if rand_split <= 0.7
	
	reg total_quantity total_embed , nocons
	predict pred_cons if train == 0, xb
	
	count if train == 0
	local test_ct = `r(N)'
	gen pred_error = (total_quantity - pred_cons)^2 if train == 0
	
	summarize pred_error, d 
	local top = `r(p99)'
	
	hist pred_error if pred_error < `top', title("Prediction Error for 2 Dim Embeddings Prediction") subtitle("Excludes > 99%-ile") graphregion(color(white))
	graph export "/Users/`whereami'/Desktop/programs/emr_nlp/embed2_linear_prederr_hist.png", replace
	
	egen mse = mean(pred_error) if train == 0
	replace mse = mse/`test_ct'
	summarize mse
	local mse_e = `r(mean)'
	
	hist pred_cons if train == 0, title("Density of Daily Consumption in Oz") subtitle("Test Data Only") note("Using top 2 embeddings for each word") graphregion(color(white))
	graph export "/Users/`whereami'/Desktop/programs/emr_nlp/embed2_linear_prediction_hist.png", replace

	
	twoway (hist total_quantity if train == 1, color(green%30))  ( hist pred_cons if train == 0, color(red%30)), legend( label(1 "Actual") label(2 "Predicted")) graphregion(color(white)) note("(Actual values based on regular expression matching)" "Word Embeddings Trained using Word2Vec") title("Predicted vs. 'Actual' Consumption Figures") subtitle("From a simple linear model x{&beta} where X is" "Sum over Words of Top 2 Embed Values" "Overall MSE - `mse_e' oz" )
	
	graph export "/Users/`whereami'/Desktop/programs/emr_nlp/embed2_linear_results.png", replace
	
		twoway (hist total_quantity if train == 1 & total_quantity < 100, color(green%30))  ( hist pred_cons if train == 0, color(red%30)), legend( label(1 "Actual") label(2 "Predicted")) graphregion(color(white)) note("(Actual values based on regular expression matching)" "Excludes training values over 100 oz/day" "Word Embeddings Trained using Word2Vec") title("Predicted vs. 'Actual' Consumption Figures") subtitle("From a simple linear model x{&beta} where X is" "Sum over Words of Top 2 Embed Values" "Overall MSE - `mse_e' oz" )
	
	graph export "/Users/`whereami'/Desktop/programs/emr_nlp/embed2_linear_results_subs.png", replace

	
* Regress on *vector* of embeddings.

	drop pred_cons pred_error mse 

	regress total_quantity embed* if train == 1, nocons
	predict pred_cons if train == 0, xb
	
	count if train == 0
	local test_ct = `r(N)'
	gen pred_error = (total_quantity - pred_cons)^2 if train == 0
	
	summarize pred_error, d 
	local top = `r(p99)'
	
	hist pred_error if pred_error < `top', title("Prediction Error for 2x22 Dimensional Prediction") subtitle("Excludes > 99%-ile") graphregion(color(white)) note("X's are a vector of embeddings where the longest " "vector has 22 words, top 2 embeddings used" "Constant Excluded")
	graph export "/Users/`whereami'/Desktop/programs/emr_nlp/embed2_highdim_prederr_hist.png", replace
	
	egen mse = mean(pred_error) if train == 0
	replace mse = mse/`test_ct'
	summarize mse
	local mse_e = `r(mean)'
	
	hist pred_cons if train == 0, title("Density of Daily Consumption in Oz" "22x2 Dim. Prediction via Embeddings ") subtitle("Test Data Only") graphregion(color(white)) note("X's are a vector of embeddings where the longest " "vector has 22 words, two embedding values per word" "Constant Excluded")
	graph export "/Users/`whereami'/Desktop/programs/emr_nlp/embed2_highdim_prediction_hist.png", replace

	
	twoway (hist total_quantity if train == 1, color(green%30))  ( hist pred_cons if train == 0, color(red%30)), legend( label(1 "Actual") label(2 "Predicted")) graphregion(color(white)) note("(Actual values based on regular expression matching)" "Word Embeddings Trained using Word2Vec" "Constant Excluded - 2 embedding values per word") title("Predicted vs. 'Actual' Consumption Figures") subtitle("From a simple linear model x{&beta} where X is" "22x2 Dimensional Word Embedding" "Overall MSE - `mse_e' oz" )
	
	graph export "/Users/`whereami'/Desktop/programs/emr_nlp/embed2_highdim_results.png", replace
	
	twoway (hist total_quantity if train == 1 & total_quantity < 100, color(green%30))  ( hist pred_cons if train == 0, color(red%30)), legend( label(1 "Actual") label(2 "Predicted")) graphregion(color(white)) note("(Actual values based on regular expression matching)" "Excludes training values over 100 oz/day" "Word Embeddings Trained using Word2Vec.  Constant Excluded." "2 embedding values per word") title("Predicted vs. 'Actual' Consumption Figures") subtitle("From a simple linear model x{&beta} where X is" "22x2 Dimensional Word Embedding" "Overall MSE - `mse_e' oz" )
	
	graph export "/Users/`whereami'/Desktop/programs/emr_nlp/embed2_highdim_results_subs.png", replace


