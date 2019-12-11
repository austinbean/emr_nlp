
/*

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
	assert freq_check <= 1
	replace frequency_measured_days = . if freq_check > 1
	replace frequency_measured_hours = . if freq_check > 1
	replace frequency_measured_times = . if freq_check > 1
  
	gen tpd = .
	replace tpd = frequency_high if frequency_measured_times == 1 & frequency_high != .
	replace tpd = 24/frequency_high if frequency_measured_hours == 1  & frequency_high != .
		* special case: frequency_measured_days is for "30 oz per day" style records.  
	*replace tpd = frequency_high if frequency_measured_days == 1 & frequency_high != .
	
	* Alt times per day (for low, when present)
	
	gen tpd_l = .
	replace tpd_l = frequency_low if frequency_measured_times == 1 & frequency_low != .
	replace tpd_l = 24/frequency_low if frequency_measured_hours == 1 & frequency_low != .  
	replace tpd_l = frequency_low if frequency_measured_days == 1 & frequency_low != .
	
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
	assert form_quant_check <= 1
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
	
	* total quantity low: 
	gen tq_l = .
	replace tq_l = quantity_low if quantity_ounce == 1 & quantity_low != .
	replace tq_l = quantity_low/(29.5) if quantity_ml == 1 & quantity_low != .
	replace tq_l = quantity_low/(29.5) if quantity_cc == 1 & quantity_low != .
			* this one is a problem - there is no conversion.
	* replace tq = quantity_low*(????) if quantity_kcal == 1 & quantity_low != .

	
	
	* Breast milk variables - goal is to get something like "total minutes" - that's probably the best we can do.  
		* this will be done as minutes / frequency 

	* BM vars:
	
	destring breast_milk_duration_low , replace
	destring breast_milk_duration_high , replace
	destring breast_milk_unclassified , replace
	
	destring breast_milk_frequency_low , replace
	destring breast_milk_frequency_high , replace
	
	destring breast_milk_measured_hours , replace
	destring breast_milk_measured_times , replace
	destring breast_milk_measured_days , replace
	destring breast_milk_measured_unclassifie , replace
	
	egen bm_quant_check = rowtotal(breast_milk_measured_hours breast_milk_measured_times breast_milk_measured_days breast_milk_measured_unclassifie)
	assert bm_quant_check <= 1
	replace breast_milk_measured_hours = . if bm_quant_check > 1 
	replace breast_milk_measured_times = . if bm_quant_check > 1 
	replace breast_milk_measured_days = . if bm_quant_check > 1 
	replace breast_milk_measured_unclassifie = . if bm_quant_check > 1
	
	* frequency - high: 
	gen bm_frq = .
	replace bm_frq =(24/breast_milk_frequency_high) if breast_milk_measured_hours == 1 & breast_milk_frequency_high != .
	replace bm_frq =breast_milk_frequency_high if breast_milk_measured_times == 1 & breast_milk_frequency_high != .
		* recall that the "days" measure is for "300 minutes per day" (quite uncommon)
		* So: don't uncomment
	* replace bm_frq =breast_milk_frequency_high if breast_milk_measured_days == 1 & breast_milk_frequency_high != .
	
	* frequency - low 
	gen bm_frq_l = .
	replace bm_frq_l = (24/breast_milk_frequency_low) if breast_milk_measured_hours == 1 & breast_milk_frequency_low != .
	replace bm_frq_l = breast_milk_frequency_low if breast_milk_measured_times == 1 & breast_milk_frequency_low != .
		
	* duration 
		* there aren't significant variations in recording this.  
	gen bm_dur = breast_milk_duration_high
	gen bm_dur_l = breast_milk_duration_low 
	
	
	* BM quantity:
	gen td_bm =  (bm_frq*bm_dur)
	label variable td_bm "total duration of breastfeeding"
	gen td_bm_l = (bm_frq_l*bm_dur_l)
	label variable td_bm_l "tot. duration breastfeeding - LOW vals"
	

	
	* SOLIDS GROUP 
	
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
