
library(tidyverse)
library(rstan)

args = commandArgs(trailingOnly=TRUE);

rstan_options("auto_write" = TRUE);

unlink(file.path(".","results"),recursive=TRUE);
dir.create(file.path(".", "results"), showWarnings = FALSE);

predict_day_count <- 30
person_id <- -1;
input_file <- "../clean_data/expd081.csv";
model_file <- "simple_categorical.stan";

if (length(args) == 0){
  print("Usage: Rscript --vanilla test.R stan_file [input_file] [person_id] [predict_day_count]")
  quit()
}

if (length(args) >= 1){
  model_file <- args[1];
}
if (length(args) >= 2){
  input_file <- args[2];  
}
if(length(args) >= 3){
  person_id <- args[3];
}
if(length(args) >= 4){
  predict_day_count <- as.numeric(args[4]);
}

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

if (person_id == -1) {
  person_id <- (data %>% sample_n(1) %>% select(USERID))[[1]]
}

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


summary_data <- list();
summary_idx <- 1;
for(par in parameters_out){
  result <- unlist(extract(
			   sample,
			   pars=parameters_out,
			   permuted=TRUE)[par],
		   use.names=FALSE);
  pred_density <- density(result, n=512);

  out <- tibble(expenditure=pred_density$x,density=pred_density$y) %>%
    filter(expenditure >= 0);

  x_max <- pred_density$x[which.max(pred_density$y)]
  quantiles <- quantile(result,c(0.05,0.95));


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

    summary_data[[summary_idx]] <- c(
				   day=as.character(idx[2]),
				   cat=as.character(map_cat),
				   low=quantiles[[1]],
				   mle=x_max,
				   high=quantiles[[2]]);
    summary_idx <- summary_idx + 1;
  }
  else {
    idx <- gsub("[^0-9]",
		"",
		sub("^[^/[]*", 
		    "", 
		    c(par)))

    file_name <- sprintf("results/density_total_day%s.csv",idx);
    write_csv(out,file_name,append=FALSE,col_names=TRUE);

    summary_data[[summary_idx]] <- c(
				   day=as.character(idx),
				   cat="-1",
				   low=quantiles[[1]],
				   mle=x_max,
				   high=quantiles[[2]]);
    summary_idx <- summary_idx + 1;
  }
}

summary_frame <- as.data.frame(do.call(rbind,summary_data)) %>%
	mutate(low=as.numeric(as.character(low)),
	       mle=as.numeric(as.character(mle)),
	       high=as.numeric(as.character(high)));

true_data <- list()
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
	  filter(category==categ,week==2) %>% 
	  pull(sum);

  print(cat_exp)
  day=1;
  for (elem in as.numeric(cat_exp)){
    true_data[[i]] <- c(day=day, cat=categ, true=elem);
    i <- i + 1;
    day <- day + 1;
  }
}

true_data <- as.data.frame(do.call(rbind,true_data)) %>%
	mutate(true=as.numeric(as.character(true)));

true_data <- rbind(true_data, 
		   true_data %>% 
			   group_by(day) %>% 
			   summarize(true=sum(true)) %>% 
			   mutate(cat=as.factor(-1)));

day_cat_compare <- full_join(true_data,summary_frame) %>% 
	mutate(true=ifelse(is.na(true),0,true),
	       low=ifelse(is.na(low),0,low),
	       mle=ifelse(is.na(mle),0,mle),
	       high=ifelse(is.na(high),0,high));

write_csv(day_cat_compare,"results/summary.csv",append=FALSE,col_names=TRUE);
print(day_cat_compare)

cat_compare <- day_cat_compare %>% 
	group_by(day) %>% 
	filter(!all(true==0)) %>% 
	ungroup() %>% 
	group_by(cat) %>% 
	summarize(true=sum(true),
		  pred=sum(mle))

write_csv(cat_compare,"results/category_summary.csv",append=FALSE,col_names=TRUE);
print(cat_compare)
