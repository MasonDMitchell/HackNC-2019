data {
  int<lower=1> N;
  int<lower=1> K;
  int<lower=1> P;
  real<lower=0> expenditure[K,P,N];
  
  int<lower=0> predict_day_count;
}
parameters {
  real<lower=0,upper=1e6> mu_expen[K];
  real<lower=0,upper=1e6> mu_person[K,P];
  real<lower=-20,upper=20> log_stdeviation[K];
  real<lower=-20,upper=20> log_stdev_person[K];
}
transformed parameters{
  real stdeviation[K] = exp(log_stdeviation);
  real stdev_person[K] = exp(log_stdev_person);
}
model {
  log_stdeviation ~ normal(0,3);
  log_stdev_person ~ normal(0,3);
  mu_expen ~ normal(150,40);
  for (categ in 1:K){
    for (person in 1:P){
      mu_person[categ,person] ~ normal(mu_expen[categ],stdeviation[categ]);
      expenditure[categ,person] ~ normal(mu_person[categ,person],stdev_person[categ]);
    }
  }
}
generated quantities{
  real<lower=0> expen_predictions[K,P,predict_day_count];
  real<lower=0> total_prediction[P,predict_day_count];
  for (day in 1:predict_day_count) {
    for (person in 1:P){
      total_prediction[person,day] = 0;
      for (categ in 1:K){
        real pred = normal_rng(mu_person[categ,person],stdev_person[categ]);
        while (pred <= 0)
          pred = normal_rng(mu_person[categ,person],stdev_person[categ]);
        expen_predictions[categ,person,day] = pred;
        total_prediction[person,day] += pred;
      }
    }
  }
}
