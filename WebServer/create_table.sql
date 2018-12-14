CREATE TABLE redirects (
  token varchar(64) NOT NULL,
  url longtext NOT NULL,
  time int(10) NOT NULL,
  constraint redirects_token_uindex
  unique (token)
);
