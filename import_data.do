/*
quick and dirty way to generate some labeled data out of string_text_diet.
want:
- identify quantities
- frequencies
- formula
- breast milk

labeled data can then be used for training

*/


* Import data and manipulate to generate training file.  
local whereami = "tuk39938"
import excel "/Users/`whereami'/Google Drive/Current Projects/CHOP EMR/String Search Diet 20101102.xls", sheet("Formula") firstrow clear


************
* CLEAN UP
************

* remove some useless strings and punctuation.
	* NOTE - wrong to remove periods, since 2.5 is valid.  
	replace string_text_diet = subinstr(string_text_diet, "DIET:", "DIET ", .)
	replace string_text_diet = subinstr(string_text_diet, ":", " ", .)
	replace string_text_diet = subinstr(string_text_diet, ",", " ", .)
	replace string_text_diet = subinstr(string_text_diet, "--", " ", .)
	replace string_text_diet = subinstr(string_text_diet, "-", " TO ", .)
	*replace string_text_diet = subinstr(string_text_diet, ".", "", .)
	replace string_text_diet = subinstr(string_text_diet, ";", " ", .)
	replace string_text_diet = subinstr(string_text_diet, "+", " ", .)
	replace string_text_diet = subinstr(string_text_diet, "(", " ", .)
	replace string_text_diet = subinstr(string_text_diet, ")", " ", .)
	replace string_text_diet = subinstr(string_text_diet, "&", " AND ", .)
	* replace double spaces with single spaces:
	replace string_text_diet = subinstr(string_text_diet, "  ", " ", .)
	replace string_text_diet = subinstr(string_text_diet, "   ", " ", .)


* Work with a duplicate of string_text_diet

gen diet = string_text_diet
browse diet




********
* replace all text number strings with the number...
********

	gen st_zero = regexm(string_text_diet, " ZERO ")
	gen rep_zero = subinstr(string_text_diet, "ZERO", "0", .) if st_zero == 1
	
	* needs spaces: "transitiONEd, dONE, nONE
	gen st_one = regexm(string_text_diet, " ONE ")
	gen rep_one = subinstr(string_text_diet, "ONE", "1", .) if st_one == 1

	gen st_two = regexm(string_text_diet, " TWO ")
	gen rep_two = subinstr(string_text_diet, "TWO", "2", .) if st_two == 1
	
	gen st_three = regexm(string_text_diet, " THREE ")
	gen rep_three = subinstr(string_text_diet, "THREE", "3", .) if st_three == 1
	
	gen st_four = regexm(string_text_diet, " FOUR ")
	gen rep_four = subinstr(string_text_diet, "FOUR", "4", .) if st_four == 1

	gen st_five = regexm(string_text_diet, " FIVE ")
	gen rep_five = subinstr(string_text_diet, "FIVE", "5", .) if st_five == 1

	gen st_six  = regexm(string_text_diet, " SIX ")
	gen rep_six = subinstr(string_text_diet, "SIX", "6", .) if st_six == 1

	gen st_seven = regexm(string_text_diet, " SEVEN ")
	gen rep_seven = subinstr(string_text_diet, "SEVEN", "7", .) if st_seven == 1
	
	gen st_eight = regexm(string_text_diet, " EIGHT ")
	gen rep_eight = subinstr(string_text_diet, " EIGHT ", "8", .) if st_eight == 1

	gen st_nine = regexm(string_text_diet, " NINE ")
	gen rep_nine = subinstr(string_text_diet, "NINE", "9", .) if st_nine == 1
	
	* watch out for this one: "often" is something you don't want to catch - add spaces 
	gen st_ten = regexm(string_text_diet, " TEN ")
	gen rep_ten = subinstr(string_text_diet, " TEN ", "10", .) if st_ten == 1

	gen st_eleven = regexm(string_text_diet, " ELEVEN ")
	gen rep_eleven = subinstr(string_text_diet, "ELEVEN", "11", .) if st_eleven == 1
	
	gen st_twelve = regexm(string_text_diet, " TWELVE ")
	gen rep_twelve = subinstr(string_text_diet, "TWELVE", "12", .) if st_twelve == 1
	
	
	
	foreach var1 of varlist st_*{
		tab `var1'
	}
	
	* Catch a few which have more than one text number
		egen changes = rowtotal(st_*)
		gen rep_all = subinstr(string_text_diet, "ZERO", "0", .) if changes > 1
		replace rep_all = subinstr(rep_all, " ONE ", "1", .) if changes > 1
		replace rep_all = subinstr(rep_all, "THREE", "3", .) if changes > 1
		replace rep_all = subinstr(rep_all, "FOUR", "4", .) if changes > 1
		replace rep_all = subinstr(rep_all, "FIVE", "5", .) if changes > 1
		replace rep_all = subinstr(rep_all, "SIX", "6", .) if changes > 1
		replace rep_all = subinstr(rep_all, "SEVEN", "7", .) if changes > 1
		replace rep_all = subinstr(rep_all, "EIGHT", "8", .) if changes > 1
		replace rep_all = subinstr(rep_all, "NINE", "9", .) if changes > 1
		replace rep_all = subinstr(rep_all, " TEN ", "10", .) if changes > 1
		replace rep_all = subinstr(rep_all, "ELEVEN", "11", .) if changes > 1
		replace rep_all = subinstr(rep_all, "TWELVE", "12", .) if changes > 1
	
	local tx_num = "one two three four five six seven eight nine ten eleven twelve"
		
	foreach var1 of local tx_num {
		
		replace diet = rep_`var1' if st_`var1' == 1 & changes == 1
	
	}
	
	* make the replacement for the combined set if 
	
	replace diet = rep_all if changes > 1 
	
	drop changes st_* rep_*

	
******
* QUANTITIES
*******
	* tag for use of ounces
	gen oz_tag = regexm(diet, "(OUNCE|OZ)")

	* replace plurals:
	replace diet = subinstr(diet, "OZS", "OZ", .) if oz_tag == 1
	replace diet = subinstr(diet, "OUNCES", "OUNCE", .) if oz_tag == 1

	* look for "ounces" as OZ - this will match "ounce" and "ounces"
	gen l_ounce = regexm(diet, "OUNCE")
	replace diet = subinstr(diet, "OUNCE", "OZ", .) if l_ounce == 1
	drop l_ounce

	* replace appearances of *OZ with * OZ
	gen unaboz = regexm(diet, "[0-9]OZ")
	gen space_oz = subinstr(diet, "OZ", " OZ", .) if unaboz == 1
	replace diet = space_oz if unaboz == 1
	drop space_oz unaboz
	
	
	* this extracts numbers prior to the string OZ
	gen str n_ounce = regexs(0) if regexm(diet, "([0-9]|[0-9][0-9]|[0-9]\.[0-9][0-9]|[0-9]\.[0-9]) +OZ")
	* remove OZ, destring
	replace n_ounce = subinstr(n_ounce, "OZ", "", .)
	destring n_ounce, replace

	* CC
	gen q_cc = regexm(diet, "CC")
	* add space if necessary
	gen unabcc = regexm(diet, "[0-9]CC")
	replace diet = subinstr(diet, "CC", " CC", .) if unabcc == 1
	* extract number and divide by 29.5 to get ounces.
	gen str n_cc = regexs(0) if regexm(diet, "([0-9]|[0-9][0-9]|[0-9]\.[0-9][0-9]|[0-9]\.[0-9]) +CC") & q_cc == 1
	replace n_cc = subinstr(n_cc, "CC", "", .)
	destring n_cc, replace
	replace n_cc = floor(n_cc/29.5)
	label variable n_cc "cc's consumed, conv to OZ"
	replace n_ounce = n_cc if n_ounce == . & q_cc == 1
	drop q_cc unabcc n_cc
	
	* ML
	gen q_ml = regexm(diet, "ML")
	* add space if necessary
	gen unabml = regexm(diet, "[0-9]ML")
	replace diet = subinstr(diet, "ML", " ML", .) if unabml == 1
	* extract number and divide by 29.5 to get ounces.
	gen str n_ml = regexs(0) if regexm(diet, "([0-9]|[0-9][0-9]|[0-9]\.[0-9][0-9]|[0-9]\.[0-9]) +ML") & q_ml == 1
	replace n_ml = subinstr(n_ml, "ML", "", .)
	destring n_ml, replace
	replace n_ml = floor(n_ml/29.5)
	label variable n_ml "ml's consumed, conv to OZ"
	replace n_ounce = n_ml if n_ounce == . & q_ml == 1
	drop q_ml unabml n_ml
	
	drop oz_tag

	****
*UNITS OF TIME / FREQUENCIES
******	
	* get hours
		gen hours_day = regexm(diet, "HOURS|HRS")
		gen unabhr = regexm(diet, "[0-9]HOURS")
		replace diet = subinstr(diet, "HOURS", " HOURS", .) if unabhr == 1
		gen hour_freq = regexs(0) if regexm(diet, "[0-9] HOURS") 
		replace hour_freq = subinstr(hour_freq, "HOURS", "", .) if hours_day == 1
		destring hour_freq, replace
		* now, can use as a freq if 24/hrs > 1
		gen times = floor(24/hour_freq) if hours_day == 1
		drop unabhr hour_freq
	* small number of kids fed every hour
		gen every_hour_m = regexm(diet, " EVERY HOUR ") // spaces matter: "HOUR "
		replace times = 24 if every_hour_m == 1

	* get "times/day"	
		gen twi_math = regexm(diet, " TWICE ")
		gen time_match = regexm(diet, "( TIMES A| TIMES EACH| TIMES PER| PER| EACH) DAY")
		gen t_freq = regexs(0) if regexm(diet, "[0-9]+( TIMES A| TIMES EACH| TIMES PER| PER| EACH) DAY")
		gen tnum = regexs(0) if regexm(t_freq, "[0-9]")
		destring tnum, replace
		replace times = tnum if time_match == 1 & times == .
		replace times = 2 if twi_math == 1 & times == .

		* limited number of uses of "daily" are inconsistent, e.g., "6 times daily" vs. "48 oz daily."
		* miscellaneous:
			* [0-9]X per day... replace X with times?  
	* look for daily, per day
		* Examples: 5X DAILY, ONCE DAILY, TWICE DAILY, 
		* OZ DAILY - can be matched.  
		* OZ A DAY - can be matched.
		* # DAILY - maybe.  
		gen aday_m = regexm(diet, "(OZ | OUNCES )A DAY")
		gen daily_m = regexm(diet, "(OUNCES |OZ )DAILY")
		gen dly_freq = regexs(0) if regexm(diet, "[0-9]+( OZ| OUNCES) DAILY")
		gen dly_num = regexs(0) if regexm(dly_freq, "[0-9][0-9]")
		destring dly_num, replace 
	
	
******************
* TOTAL QUANTITY *
******************
	
	gen total_quantity = .
	replace total_quantity = times*n_ounce if hours_day == 1 & total_quantity == .
	replace total_quantity = times*n_ounce if time_match == 1 & total_quantity == .
	replace total_quantity = dly_num if aday_m == 1 | daily_m == 1
	browse diet total_quantity


keep if total_quantity != .


	* what will be tricky here is that it has to learn the quantity and frequency.
	* This is actually a reasonably complicated transformation of the original data.
	* Let's see if it's learnable... 
keep diet total_quantity
export delimited "/Users/`whereami'/Desktop/programs/emr_nlp/data.csv", replace




/*
	
*************
* TYPE OF FOOD
*************		
		
		
* breast milk
	gen breast_milk = regexm(diet, "BREAST")
	gen bmins = regexm(diet, "(MINS|MINUTE)") if breast_milk == 1
	* extract the minutes if b_m == 1
	
	
* formula
	gen formula = regexm(diet, "NEOSURE|ENFAMIL|ENFACARE|NUTRAMIGEN|FORMULA|ALIMENTUM|SIMILAC|CARNATION|ISOMIL")
	
* should do ML too.
* and CC

* note that ad lib will be pretty hard to categorize

*/
