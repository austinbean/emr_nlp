* as robustness... "random embeddings"

	clear 
	local whereami = "tuk39938"
	import delimited "/Users/`whereami'/Desktop/programs/emr_nlp/data.csv",   clear


* Split diet variable into individual words - total vocabulary is quite small.
	split diet, p(" ") gen(word)
	gen patid = _n
	reshape long word, i(patid) j(wct)
	drop if word == ""

* random embeddings 
	gen embed = rnormal()
	
	reshape wide word embed , i(patid) j(wct)

	
	foreach nm of numlist 1(1)22{
		replace embed`nm' = 0 if embed`nm' == .
	}
	
* prediction w/ random data.  
	set seed 41 
	gen rand_split = runiform()
	gen train = 0
	replace train = 1 if rand_split <= 0.7
	

	regress total_quantity embed* if train == 1
	predict pred_cons if train == 0, xb
	
	count if train == 0
	local test_ct = `r(N)'
	gen pred_error = (total_quantity - pred_cons)^2 if train == 0
	
	summarize pred_error, d 
	local top = `r(p99)'
	
	hist pred_error if pred_error < `top', title("Prediction Error for 22 Dimensional Prediction") subtitle("Excludes > 99%-ile") graphregion(color(white)) note("X's are a vector of N(0,1) random numbers" "where the longest vector has 22 words")
	graph export "/Users/`whereami'/Desktop/programs/emr_nlp/rand_embed_prederr_hist.png", replace
	
	egen mse = mean(pred_error) if train == 0
	replace mse = mse/`test_ct'
	summarize mse
	local mse_e = `r(mean)'
	
	hist pred_cons if train == 0, title("Density of Daily Consumption in Oz" "22 Dim. Prediction via Random Numbers ") subtitle("Test Data Only") graphregion(color(white)) note("X's are a vector of N(0,1) random numbers" "where the longest vector has 22 words")
	graph export "/Users/`whereami'/Desktop/programs/emr_nlp/rand_embed_prediction_hist.png", replace

	
	twoway (hist total_quantity if train == 1, color(green%30))  ( hist pred_cons if train == 0, color(red%30)), legend( label(1 "Actual") label(2 "Predicted")) graphregion(color(white)) note("(Actual values based on regular expression matching)" "Word Embeddings are Random N(0,1) Values") title("Predicted vs. 'Actual' Consumption Figures") subtitle("From a simple linear model x{&beta} where X is" "22 Dimensional Word Random Number" "Overall MSE - `mse_e' oz" )
	
	graph export "/Users/`whereami'/Desktop/programs/emr_nlp/rand_embed_results.png", replace
	
	twoway (hist total_quantity if train == 1 & total_quantity < 100, color(green%30))  ( hist pred_cons if train == 0, color(red%30)), legend( label(1 "Actual") label(2 "Predicted")) graphregion(color(white)) note("(Actual values based on regular expression matching)" "Excludes training values over 100 oz/day" "Word Embeddings are Random N(0,1) Values") title("Predicted vs. 'Actual' Consumption Figures") subtitle("From a simple linear model x{&beta} where X is" "22 Dimensional Word Embedding" "Overall MSE - `mse_e' oz" )
	
	graph export "/Users/`whereami'/Desktop/programs/emr_nlp/rand_embed_results_subs.png", replace

