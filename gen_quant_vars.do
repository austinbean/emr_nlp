
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
			
		/*
		QUANTITY MEASURES:
		quantity_low quantity_high
		
		QUANTITY UNIT MEASURES:
		quantity_ounces quantity_ml quantity_cc quantity_kcal quantity_unclassified
		
		FREQUENCY MEASURES:
		frequency_low frequency_high
		
		FREQUENCY UNIT MEASURES:
		frequency_measured_hours frequency_measured_days frequency_measured_times frequency_unclassified
		
		
		*/
		* start with: get times per day, then quantity.
		
		* Times Per Day:
		gen tpd = .
		replace tpd = frequency_high if frequency_measured_times == 1
		replace tpd = 24/frequency_high if frequency  
		
		
		
		
		
		
		replace tq = quantity_ounces*quantity_high*frequency_low if frequency_measured_times == 1
		replace tq = quantity_ounces*quantity_high*(24/frequency_measured_hours) if fequency_measured_hours == 1
		replace tq = quantity_ounces*quantity_high*
