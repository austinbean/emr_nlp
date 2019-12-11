
/*

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

breast_milk_duration_low 
breast_milk_duration_high 
breast_milk_unclassified 

breast_milk_frequency_low 
breast_milk_frequency_high 
breast_milk_measured_hours 
breast_milk_measured_times 
breast_milk_measured_days 
breast_milk_measured_unclassifie 

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

spits_up 
GERD 
CAUTION 
food_typo 
typos 
diet_text

*/



	* now generate some quantities.  
		* there are a lot of possible combinations here.
		* Need to do: frequency, quantity, then combine, but remember to check 0/missing.
	
		gen tq = .
			* There is much more to think through here and variables we want to make sure are nonmissing!  
			

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
			* There is one bad value - what to do with it?  Drop or fix.  
		gen tpd = .
		replace tpd = frequency_high if frequency_measured_times == 1 & frequency_high != .
		replace tpd = 24/frequency_high if frequency_measured_hours == 1  & frequency_high != .
		replace tpd = frequency_high if frequency_measured_days == 1 & frequency_high != .
		
		* Alt times per day (for low, when present)
		
		gen tpd_l = .
		replace tpd_l = frequency_low if frequency_measured_times == 1 & frequency_low != .
		replace tpd_l = 24/frequency_low if frequency_measured_hours == 1 & frequency_low != .  
		replace tpd_l = frequency_low if frequency_measured_days == 1 & frequency_low != .
		
		* probably check something about whether there are quantities present AND ad_lib == 1

		
	* Quantity variables:
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
	
	* total quantity (in mL):
	gen tq = .
	replace tq = quantity_high if quantity_ml == 1 & quantity_high != .

