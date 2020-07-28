
/*

See data_imp_clean.do as well.  

Split into several different, related ideas.  Want to classify: formula, BM, solids, juice, spitting up.  This is five separate ideas.  

TODO - review codebook entry for frequency days.  
Var Names:

Replicate 
id 
visit_id 
dol_contact_date 
visit_num line 
note_text 
note_text_noid 
curr_loc 

no_diet_recorded 

	* formula-related measures.  
quantity_low 
quantity_high 
quantity_ounces 
quantity_ml 
quantity_cc 
quantity_kcal 
quantity_unclassified 

frequency_low 
frequency_high 
frequency_measured_hours 
frequency_measured_days 
frequency_measured_times 
frequency_unclassified 

formula_ad_lib 
breast_milk_ad_lib 
formula 
breast_milk 


	* breast milk related measures.  
breast_milk_duration_low 
breast_milk_duration_high 
breast_milk_unclassified 

breast_milk_frequency_low 
breast_milk_frequency_high 
breast_milk_measured_hours 
breast_milk_measured_times 
breast_milk_measured_days 
breast_milk_measured_unclassifie 


	* Solids are a separate task to perform.  
solids_mentioned 
solids_quantity_low 
solids_quantity_high 
solids_quantity_ounces 
solids_quantity_ML 
solids_quantity_CC 
solids_quantity_KCAL 
solids_quantity_unclassified 

solids_frequency_low 
solids_frequency_high 
solids_frequency_hours 
solids_frequency_days 
solids_frequency_times 
solids_frequency_unclassified 


	* a juice task -> this is a separate outcome to measure.
juice_mentioned 
juice_quantity_low 
juice_quantity_high 
juice_quantity_ounces 
juice_quantity_ML 
juice_quantity_CC 
juice_quantity_KCAL 
juice_quantity_unclassified 

juice_frequency_low 
juice_frequency_high 
juice_frequency_hours 
juice_frequency_days 
juice_frequency_times 
juice_frequency_unclassified 


	* these two can be used as a separate classification task
	spits_up 
	GERD
	
CAUTION 
food_typo 
typos 
diet_text

*/


* Formula variables: goal should be to get something like low and high estimates for quantity, when available.


* Times Per Day (this is for formula):
	destring frequency_high, replace
	destring frequency_low, replace
		* Other formula vars:
	destring formula_ad_lib, replace 
		* look for problem records where there is more than one frequency measure recorded 
	destring frequency_measured_days, replace
	destring frequency_measured_hours, replace
	destring frequency_measured_times, replace
	egen freq_check = rowtotal(frequency_measured_*)
	*assert freq_check <= 1
	replace frequency_measured_days = . if freq_check > 1
	replace frequency_measured_hours = . if freq_check > 1
	replace frequency_measured_times = . if freq_check > 1
  
	gen tpd = .
	replace tpd = frequency_high if frequency_measured_times == 1 & frequency_high != .
	replace tpd = 24/frequency_high if frequency_measured_hours == 1  & frequency_high != .
		* special case: frequency_measured_days is for "30 oz per day" style records. 
		* This may also be 8 times per day.
	replace tpd = frequency_high if frequency_measured_days == 1 & frequency_high != .
	label variable tpd "times per day"
	* Alt times per day (for low, when present)
	
	gen tpd_l = .
	replace tpd_l = frequency_low if frequency_measured_times == 1 & frequency_low != .
	replace tpd_l = 24/frequency_low if frequency_measured_hours == 1 & frequency_low != .  
		* special case: frequency_measured_days is for "30 oz day"
		* This can also be - 8 times per day
	replace tpd_l = frequency_low if frequency_measured_days == 1 & frequency_low != .
	label variable tpd_l "times per day, low estimate"
	
	* probably check something about whether there are quantities present AND ad_lib == 1

		
* Formula Quantity variables:
	destring quantity_low, replace
	destring quantity_high, replace
	
	destring quantity_ounce, replace 
	destring quantity_ml, replace
	destring quantity_cc, replace
	destring quantity_kcal, replace
	
	destring quantity_unclassified, replace
	
	* check quantity variables
	egen form_quant_check = rowtotal(quantity_ounce quantity_ml quantity_cc quantity_kcal quantity_unclassified)
	 *assert form_quant_check <= 1
	replace quantity_ounce = . if form_quant_check > 1 
	replace quantity_ml = . if form_quant_check > 1 
	replace quantity_cc = . if form_quant_check > 1
	replace quantity_kcal = . if form_quant_check > 1
	replace quantity_unclassified = . if form_quant_check > 1
	
	* total quantity (in mL):
	gen tq = .
	replace tq = quantity_high if quantity_ounce == 1 & quantity_high != .
	replace tq = quantity_high/(29.5) if quantity_ml == 1 & quantity_high != .
	replace tq = quantity_high/(29.5) if quantity_cc == 1 & quantity_high != .
		* this one is a problem - there is no conversion.
	* replace tq = quantity_high*(????) if quantity_kcal == 1 & quantity_high != .
	label variable tq "total quantity formula"
	
	* total quantity low: 
	gen tq_l = .
	replace tq_l = quantity_low if quantity_ounce == 1 & quantity_low != .
	replace tq_l = quantity_low/(29.5) if quantity_ml == 1 & quantity_low != .
	replace tq_l = quantity_low/(29.5) if quantity_cc == 1 & quantity_low != .
			* this one is a problem - there is no conversion.
	* replace tq = quantity_low*(????) if quantity_kcal == 1 & quantity_low != .
	label variable tq_l "total quantity formula, low estimate"
	
	
	* Combined formula quantity measures:
	gen total_formula = tq*tpd 
	label variable total_formula "total formula consumed"
	gen total_formula_low = tq_l*tpd_l
	label variable total_formula_low "total formula consumed, low estimate"
	
	
* Breast milk variables - goal is to get something like "total minutes" - that's probably the best we can do.  
	* this will be done as minutes / frequency 

	* BM Duration
	destring breast_milk_duration_low , replace
	destring breast_milk_duration_high , replace
	destring breast_milk_unclassified , replace
	
	destring breast_milk_frequency_low , replace
	destring breast_milk_frequency_high , replace
	
	destring breast_milk_measured_hours , replace
	destring breast_milk_measured_times , replace
	destring breast_milk_measured_days , replace // this would be for an unlikely "300 minutes per day" category
	destring breast_milk_measured_unclassifie , replace
	
	egen bm_quant_check = rowtotal(breast_milk_measured_hours breast_milk_measured_times breast_milk_measured_days breast_milk_measured_unclassifie)
	*assert bm_quant_check <= 1
	replace breast_milk_measured_hours = . if bm_quant_check > 1 
	replace breast_milk_measured_times = . if bm_quant_check > 1 
	replace breast_milk_measured_days = . if bm_quant_check > 1 
	replace breast_milk_measured_unclassifie = . if bm_quant_check > 1
	
	* BM frequency variables. 
	
	* BM frequency - high: 
	gen bm_frq = .
	replace bm_frq =(24/breast_milk_frequency_high) if breast_milk_measured_hours == 1 & breast_milk_frequency_high != .
	replace bm_frq =breast_milk_frequency_high if breast_milk_measured_times == 1 & breast_milk_frequency_high != .
		* recall that the "days" measure is for "300 minutes per day" (quite uncommon)
		* This could be for a "total times per day"
	replace bm_frq =breast_milk_frequency_high if breast_milk_measured_days == 1 & breast_milk_frequency_high != .
	label variable bm_frq "breast milk frequency"
	* BM frequency - low 
	gen bm_frq_l = .
	replace bm_frq_l = (24/breast_milk_frequency_low) if breast_milk_measured_hours == 1 & breast_milk_frequency_low != .
	replace bm_frq_l = breast_milk_frequency_low if breast_milk_measured_times == 1 & breast_milk_frequency_low != .
		* _measured_days case treated separately below.  
	label variable bm_frq_l "breast milk frequency, low estimate"
	
	* BM duration 
		* there aren't significant variations in recording this.  
	gen bm_dur = breast_milk_duration_high
	label variable bm_dur "breast feeding duration"
	gen bm_dur_l = breast_milk_duration_low 
	label variable bm_dur_l "breast feeding duration, low estimate"
	
	
	* BM quantity:
	gen td_bm =  (bm_frq*bm_dur)
	replace td_bm = breast_milk_duration_high if breast_milk_measured_days == 1
	label variable td_bm "total duration of breastfeeding"
		* low 
	gen td_bm_l = (bm_frq_l*bm_dur_l)
	replace td_bm_l = breast_milk_duration_low if breast_milk_measured_days == 1
	label variable td_bm_l "tot. duration breastfeeding - LOW estimate"
	

	
	* SOLIDS GROUP 
			* condition all of these on solids mentioned?
	destring solids_mentioned , replace
		* Quantity Measures
	destring solids_quantity_low , replace 
	destring solids_quantity_high , replace 
	
	destring solids_quantity_ounces , replace 
	destring solids_quantity_ML , replace 
	destring solids_quantity_CC , replace 
	destring solids_quantity_KCAL , replace 
	destring solids_quantity_unclassified , replace 
		* there is a "total quantity per day" category here missing, if that exists. There is one for the frequency measure.
		* none of these are available - no one records in this way.    Can do frequency but not total quantity.  
	egen sol_q_check = rowtotal(solids_quantity_*)
	replace solids_quantity_ounces = . if sol_q_check > 1 
	replace solids_quantity_ML = . if sol_q_check > 1
	replace solids_quantity_CC = . if sol_q_check > 1 
	replace solids_quantity_KCAL = . if sol_q_check > 1
	
	* Quantity 
	gen s_q = .
	replace s_q = solids_quantity_high if solids_quantity_ML == 1
	replace s_q = (solids_quantity_high/(29.5)) if solids_quantity_CC == 1
	replace s_q = (solids_quantity_high/(29.5)) if solids_quantity_KCAL == 1
	label variable s_q "solids quantity"
	
	* low 
	gen s_q_l = .
	replace s_q_l = solids_quantity_low if solids_quantity_low != . & solids_quantity_ML == 1
	replace s_q_l = (solids_quantity_low/(29.5)) if solids_quantity_low != . & solids_quantity_CC == 1
	replace s_q_l = (solids_quantity_low/(29.5)) if solids_quantity_low != . & solids_quantity_KCAL == 1
	label variable s_q_l "solids quantity - low estimate"
	
		* Frequency measures
	destring solids_frequency_low , replace
	destring solids_frequency_high , replace
	
	destring solids_frequency_hours , replace
	destring solids_frequency_days , replace
	destring solids_frequency_times , replace
	destring solids_frequency_unclassified , replace
	
	egen sol_freq_check = rowtotal(solids_frequency_*)
	replace solids_frequency_hours = . if sol_freq_check > 1
	replace solids_frequency_days = . if sol_freq_check > 1
	replace solids_frequency_times = . if sol_freq_check > 1
	replace solids_frequency_unclassified = . if sol_freq_check > 1
	
	* totals 
	gen s_f = .
	replace s_f = solids_frequency_high if solids_frequency_times == 1 
	replace s_f = (24/solids_frequency_high) if solids_frequency_hours == 1 
		* the day value is special, but there isn't a matching quantity value to make sense of it
	* replace s_f =  solids_frequency_high if solids_frequency_high == 1 
	label variable s_f "solids frequency"
	
	* totals low 
	gen s_f_l = .
	replace s_f_l = solids_frequency_low if solids_frequency_times == 1 & solids_frequency_low != .
	replace s_f_l = (24/solids_frequency_low) if solids_frequency_hours == 1 & solids_frequency_low != .
		* the day value is special, but there isn't a matching quantity value to make sense of it
	* replace s_f_l =  solids_frequency_low if solids_frequency_low == 1 
	label variable s_f_l "solids frequency - low estimate"
	
	* Solid foods total:
	gen solid_total = s_f*s_q 
	label variable solid_total "total quant solids"
	gen solid_total_low = s_f_l*s_q_l 
	label variable solid_total_low "total quant solids, low estimate"
	
	
	* JUICE GROUP 
		* indicated
	destring juice_mentioned , replace
		* quantity measures
	destring juice_quantity_low , replace
	destring juice_quantity_high , replace
	
	destring juice_quantity_ounces , replace
	destring juice_quantity_ML , replace
	destring juice_quantity_CC , replace
	destring juice_quantity_KCAL , replace
	destring juice_quantity_unclassified , replace
	
	egen juice_q_check = rowtotal(juice_quantity*)
	replace juice_quantity_ML = . if juice_q_check > 1
	replace juice_quantity_CC = . if juice_q_check > 1
	replace juice_quantity_KCAL = . if juice_q_check > 1
	replace juice_quantity_unclassified = . if juice_q_check > 1
	
	* Quantity 
	gen j_q = .
	replace j_q = juice_quantity_high if juice_quantity_ML == 1
	replace j_q = (juice_quantity_high/(29.5)) if juice_quantity_CC == 1
	replace j_q = (juice_quantity_high/(29.5)) if juice_quantity_KCAL == 1
	label variable j_q "juice quantity"
	
	* low 
	gen j_q_l = .
	replace j_q_l = juice_quantity_low if juice_quantity_low != . & juice_quantity_ML == 1
	replace j_q_l = (juice_quantity_low/(29.5)) if juice_quantity_low != . & juice_quantity_CC == 1
	replace j_q_l = (juice_quantity_low/(29.5)) if juice_quantity_low != . & juice_quantity_KCAL == 1
	label variable j_q_l "juice quantity - low estimate"
	
		* frequency measures. 
	destring juice_frequency_low , replace
	destring juice_frequency_high , replace
	
	destring juice_frequency_hours , replace
	destring juice_frequency_days , replace
	destring juice_frequency_times , replace
	destring juice_frequency_unclassified , replace

	egen juice_f_check = rowtotal(juice_frequency_*)
	replace juice_frequency_hours = . if juice_f_check > 1
	replace juice_frequency_days = . if juice_f_check > 1
	replace juice_frequency_times = . if juice_f_check > 1
	replace juice_frequency_unclassified = . if juice_f_check > 1
	
		* totals 
	gen j_f = .
	replace j_f = juice_frequency_high if juice_frequency_times == 1 
	replace j_f = (24/juice_frequency_high) if juice_frequency_hours == 1 
		* the day value is special, but there isn't a matching quantity value to make sense of it
	* replace j_f =  juice_frequency_high if juice_frequency_high == 1 
	label variable j_f "juice frequency "
	
	* totals low 
	gen j_f_l = .
	replace j_f_l = juice_frequency_low if juice_frequency_times == 1 & juice_frequency_low != .
	replace j_f_l = (24/juice_frequency_low) if juice_frequency_hours == 1 & juice_frequency_low != .
		* the day value is special, but there isn't a matching quantity value to make sense of it
	* replace j_f_l =  juice_frequency_low if juice_frequency_low == 1 
	label variable j_f_l "juice frequency, low estimate"
	
	* Solid foods total:
	gen juice_total = j_f*j_q 
	label variable juice_total "juice total quantity"
	gen juice_total_low = j_f_l*j_q_l 
	label variable juice_total_low "juice total quantity, low estimate"
	
	

	* SPIT UP GROUP
	destring spits_up, replace 
	destring GERD, replace
	gen spit_up = .
	replace spit_up = 1 if 	spits_up == 1 | GERD == 1
	label variable spit_up "ind of some significant vomiting"
	
* get rid of check variables:
	drop *_check
	
	
	// Just keep ID variables and the generated values, then merge back w/ the diet text.  
