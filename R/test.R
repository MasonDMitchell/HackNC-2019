
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

cleaned_data <- list()
i <- 1
for (categ in person_categories){
  cat("Preparing category",format(as.numeric(categ)),"\n");

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
  cleaned_data[[i]] <- cat_exp;
  i <- i + 1;
}

cleaned_data <- do.call(rbind,cleaned_data);

print(cleaned_data)

sample <- sampling(model,
	     data=list(N=dim(cleaned_data)[2],
		       K=dim(cleaned_data)[1],
		       expenditure=cleaned_data,
		       predict_day_count=predict_day_count),
	     verbose=FALSE);

print(sample)

combins <- expand.grid(categ=1:dim(cleaned_data)[1],day=1:predict_day_count);
parameters_out <- c(sprintf("expen_predictions[%s,%s]",combins[["categ"]],combins[["day"]]),
		    sprintf("total_prediction[%s]",1:predict_day_count));

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

  if(startsWith(par,"expen")){

    idx <- strsplit(
	   gsub("[^0-9,]",
		"",
		sub("^[^/[]*", 
		    "", 
		    c(par))),
		",")[[1]]

    map_cat <- person_categories[as.numeric(idx[1])];

    file_name <- sprintf("results/density_cat%s_day%s.csv",map_cat,idx[2]);
    write_csv(out,file_name,append=FALSE,col_names=TRUE);
  }
  else {
    idx <- gsub("[^0-9]",
		"",
		sub("^[^/[]*", 
		    "", 
		    c(par)))

    file_name <- sprintf("results/density_total_day%s.csv",idx);
    write_csv(out,file_name,append=FALSE,col_names=TRUE);
  }
}


