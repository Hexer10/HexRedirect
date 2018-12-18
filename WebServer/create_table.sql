CREATE TABLE redirects (
  token varchar(64) NOT NULL UNIQUE,
  url longtext NOT NULL,
  time int(10) NOT NULL
);
