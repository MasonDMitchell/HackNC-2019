
library(tidyverse)
library(rstan)

rstan_options("auto_write" = TRUE)

data <- read_csv("../clean_data/expd081.csv")
data <- data %>% 
	mutate(
	       date = ISOdate(year,month,day),
	       wday = weekdays(date),
	       week=factor(NEWID%%10),
	       USERID=factor(NEWID%/%10)) %>% 
	group_by(USERID,week) %>% 
	mutate(min_date = min(date), 
	       days_in = as.numeric(
		difftime(date,min_date,units="days"))) %>% 
	select(-year,-month,-day,-NEWID,-min_date) %>% 
	ungroup()

model <- stan_model("simple_categorical.stan",
		    model_name="simple")

person_id <- (data %>% sample_n(1) %>% select(USERID))[[1]]
person_data <- data %>% filter(USERID == person_id)

cat_2_exp <- person_data %>% 
	group_by(category,week,days_in) %>% 
	summarize(sum=sum(COST)) %>% 
	ungroup() %>% 
	filter(category==2,week==1) %>% 
	pull(sum)

sample <- sampling(model,
		   data=list(N=length(cat_2_exp),
			     expenditure=cat_2_exp,
			     predict_day_count=7))

print(sample)

