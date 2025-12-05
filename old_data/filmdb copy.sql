PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE countries(country_code char(2) not null
                                 constraint "country code length"
                                   check(length(country_code)<=2),
                       country_name varchar(50) not null
                                 constraint "country name length"
                                   check(length(country_name)<=50),
                       continent    varchar(20) not null
                                 constraint "continent length"
                                   check(length(continent)<=20),
                       primary key(country_code),
                       unique(country_name));
INSERT INTO countries VALUES('cd','Congo Kinshasa','AFRICA');
INSERT INTO countries VALUES('ci','Cote d''Ivoire','AFRICA');
INSERT INTO countries VALUES('dj','Djibouti','AFRICA');
INSERT INTO countries VALUES('eg','Egypt','AFRICA');
CREATE TABLE movies(movieid       integer not null primary key,
                    title         varchar(100) not null
                                 constraint "title length"
                                   check(length(title)<=100),
                    country       char(2) not null
                                 constraint "country length"
                                   check(length(country)<=2),
                    year_released int not null
                                 constraint "year_released numerical"
                                   check(year_released+0=year_released),
                    runtime        int
                                 constraint "runtime numerical"
                                   check(runtime+0=runtime),
                    unique(title, country, year_released),
                    foreign key(country) references countries(country_code));
INSERT INTO movies VALUES(23,'Dhum Dhadaka','in',1985,148);
INSERT INTO movies VALUES(24,'Diarios de motocicleta','pe',2004,126);
INSERT INTO movies VALUES(25,'Dil Chahta Hai','in',2001,184);
CREATE TABLE people(peopleid   integer not null primary key,
                    first_name varchar(30) null
                                 constraint "first_name length"
                                   check(length(first_name)<=30),
                    surname    varchar(30) not null
                                 constraint "surname length"
                                   check(length(surname)<=30),
                    born       int not null
                                 constraint "born numerical"
                                   check(born+0=born),
                    died       int null
                                 constraint "died numerical"
                                   check(died+0=died),
                    gender     char(1) not null default '?',
                    unique(surname, first_name));
INSERT INTO people VALUES(10646,'Anthony','Newley',1931,1999,'M');
INSERT INTO people VALUES(10647,'Barry','Newman',1938,NULL,'M');
CREATE TABLE credits(movieid     int not null,
                     peopleid    int not null,
                     credited_as char(1) not null
                                 constraint "credited_as length"
                                   check(length(credited_as)=1),
                     primary key(movieid, peopleid, credited_as),
                     foreign key(movieid) references movies(movieid),
                     foreign key(peopleid) references people(peopleid));
INSERT INTO credits VALUES(2170,15580,'A');
INSERT INTO credits VALUES(2170,12257,'D');
INSERT INTO credits VALUES(2170,6057,'A');
CREATE TABLE alt_titles
       (titleid  integer not null primary key,
        movieid  int,
        title    varchar(250) not null,
        unique(movieid, title),
        foreign key (movieid) references movies(movieid)
            on delete cascade);
INSERT INTO alt_titles VALUES(1441,8580,'Take Off');
INSERT INTO alt_titles VALUES(1442,8580,'국가대표');
INSERT INTO alt_titles VALUES(1443,8101,'Kundo: Age of the Rampant');
CREATE TABLE movie_title_ft_index2
       (title_word    varchar(50) not null,
        movieid       int not null,
        titleid       int default 1 not null,
        primary key(title_word, movieid, titleid),
        foreign key (movieid) references movies(movieid)
            on delete cascade,
        foreign key(titleid) references alt_titles(titleid));
COMMIT;
