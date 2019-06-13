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

import excel "/Users/austinbean/Desktop/programs/emr_nlp/String Search Diet 20101102.xls", sheet("Formula") firstrow clear



* Work with a duplicate of string_text_diet

gen diet = string_text_diet
browse diet

* replace all text number strings with the number...
	gen st_zero = regexm(string_text_diet, "ZERO")
	gen rep_zero = subinstr(string_text_diet, "ZERO", "0", .) if st_zero == 1
	
	* needs spaces: "transitiONEd, dONE, nONE
	gen st_one = regexm(string_text_diet, " ONE ")
	gen rep_one = subinstr(string_text_diet, "ONE", "1", .) if st_one == 1

	gen st_two = regexm(string_text_diet, "TWO")
	gen rep_two = subinstr(string_text_diet, "TWO", "2", .) if st_two == 1
	
	gen st_three = regexm(string_text_diet, "THREE")
	gen rep_three = subinstr(string_text_diet, "THREE", "3", .) if st_three == 1
	
	gen st_four = regexm(string_text_diet, "FOUR")
	gen rep_four = subinstr(string_text_diet, "FOUR", "4", .) if st_four == 1

	gen st_five = regexm(string_text_diet, "FIVE")
	gen rep_five = subinstr(string_text_diet, "FIVE", "5", .) if st_five == 1

	gen st_six  = regexm(string_text_diet, "SIX")
	gen rep_six = subinstr(string_text_diet, "SIX", "6", .) if st_six == 1

	gen st_seven = regexm(string_text_diet, "SEVEN")
	gen rep_seven = subinstr(string_text_diet, "SEVEN", "7", .) if st_seven == 1
	
	gen st_eight = regexm(string_text_diet, "EIGHT")
	gen rep_eight = subinstr(string_text_diet, "EIGHT", "8", .) if st_eight == 1

	gen st_nine = regexm(string_text_diet, "NINE")
	gen rep_nine = subinstr(string_text_diet, "NINE", "9", .) if st_nine == 1
	
	* watch out for this one: "often" is something you don't want to catch
	gen st_ten = regexm(string_text_diet, " TEN ")
	gen rep_ten = subinstr(string_text_diet, " TEN ", "10", .) if st_ten == 1

	gen st_eleven = regexm(string_text_diet, "ELEVEN")
	gen rep_eleven = subinstr(string_text_diet, "ELEVEN", "11", .) if st_eleven == 1
	
	gen st_twelve = regexm(string_text_diet, "TWELVE")
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

* look for "ounces" as OZ
	gen l_ounce = regexm(diet, "OUNCE")
	replace diet = subinstr(diet, " OUNCE ", "OZ", .) if l_ounce == 1
	drop l_ounce

	gen ounce = regexm(diet, "OZ")
	
	gen qoz = regexm(diet, "[0-9].+OZ")

	* replace appearances of *OZ with * OZ
	gen unaboz = regexm(diet, "[0-9]OZ")
	gen space_oz = subinstr(diet, "OZ", " OZ", .) if unaboz == 1
	replace diet = space_oz if unaboz == 1
	drop space_oz unaboz
	
	* this extracts numbers prior to the string OZ
		* is this messing up two-digit numbers?
	gen str n_ounce = regexs(0) if regexm(diet, "([0-9]|[0-9][0-9]|[0-9]\.[0-9][0-9]|[0-9]\.[0-9]) +OZ")
	* remove OZ, destring
	replace n_ounce = subinstr(n_ounce, "OZ", "", .)
	destring n_ounce, replace

	
* get hours
	gen hours_day = regexm(diet, "[0-9] HOURS")
	gen hour_freq = regexs(0) if regexm(diet, "[0-9] HOURS")
	gen hour_every = regexm(diet, "EVERY [0-9] HOURS")
	
* get daily
	gen q_daily = regexm(diet, " DAILY | DAY ")


* get "times/day"	
drop time_match
	gen time_match = regexm(diet, "TIMES+( DAY | EACH DAY)")

* breast milk
	gen breast_milk = regexm(diet, "BREAST")
	
* formula
	gen formula = regexm(diet, "NEOSURE|ENFAMIL|ENFACARE|NUTRAMIGEN|FORMULA|ALIMENTUM|SIMILAC|CARNATION|ISOMIL")
	
* should do ML too.
* and CC

* note that ad lib will be pretty hard to categorize
