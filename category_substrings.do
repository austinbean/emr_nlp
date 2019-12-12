* identify categories:

gen caps = ustrregexm(diet_text, "\w(?=:)" )
