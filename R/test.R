
library(tidyverse)
library(rstan)

rstan_options("auto_write" = TRUE)

dir.create(file.path(".", "results"), showWarnings = FALSE)

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
	ungroup() %>%
	mutate(days_in = factor(days_in),
	       category = factor(category))

bad_ids <- data %>% 
	group_by(USERID,week,.drop=FALSE) %>% 
	summarize(sum = sum(COST)) %>% 
	summarize(min_count=min(sum)) %>% 
	filter(min_count == 0) %>% 
	pull(USERID)

data <- data %>% filter(!USERID %in% bad_ids)

model <- stan_model("simple_categorical.stan",
		    model_name="simple")

person_id <- (data %>% sample_n(1) %>% select(USERID))[[1]]
person_data <- data %>% filter(USERID == person_id)
person_categories <- person_data %>% 
	filter(week == 1) %>% 
	select(category) %>% 
	unique() %>% 
	pull(category)
person_days <- person_data %>% 
	filter(week == 1) %>% 
	select(days_in) %>% 
	unique() %>% 
	pull(days_in);
print(person_days)

substrRight <- function(x, n){
  substr(x, nchar(x)-n+1, nchar(x))
}

predict_day_count <- 7
parameters_out <- sprintf("expen_predictions[%s]",1:predict_day_count);

for (categ in person_categories){
  cat("Sampling category",format(as.numeric(categ)),"\n");

  cat_exp <- person_data %>%
	  mutate(inter = interaction(category,week)) %>%
	  group_by(inter,days_in,.drop=FALSE) %>% 
	  summarize(sum=sum(COST),
		    category=first(na.omit(category)),
		    week=first(na.omit(week))) %>% 
	  mutate(category=first(na.omit(category)),
		 week=first(na.omit(week))) %>%
	  ungroup() %>% 
	  filter(category==categ,week==1) %>% 
	  pull(sum);

  print(cat_exp)

  sample <- sampling(model,
  		     data=list(N=length(cat_exp),
			       expenditure=cat_exp,
			       predict_day_count=predict_day_count),
		     verbose=FALSE);

  print(sample)
  result <- extract(sample,pars=parameters_out,permuted=TRUE);

  for(par in parameters_out){
    pred_density <- density(
			    unlist(extract(
				     sample,
				     pars=parameters_out,
				     permuted=TRUE)[par],
			    	   use.names=FALSE),
			    n=512);

    out <- tibble(expenditure=pred_density$x,density=pred_density$y) %>%
	    filter(expenditure >= 0);

    file_name <- sprintf("results/density_%s_%s.csv",categ,par);
    write_csv(out,file_name,append=FALSE,col_names=TRUE);
  }
}

