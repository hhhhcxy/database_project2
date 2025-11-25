PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE merge_people(id int, should_be_id int);
INSERT INTO merge_people VALUES(1133,1134);
INSERT INTO merge_people VALUES(9822,9823);
INSERT INTO merge_people VALUES(12438,12439);
INSERT INTO merge_people VALUES(12625,12626);
INSERT INTO merge_people VALUES(12777,12780);
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
CREATE TABLE credits(movieid     int not null,
                     peopleid    int not null,
                     credited_as char(1) not null
                                 constraint "credited_as length"
                                   check(length(credited_as)=1),
                     primary key(movieid, peopleid, credited_as),
                     foreign key(movieid) references movies(movieid),
                     foreign key(peopleid) references people(peopleid));
CREATE TABLE forum_members
     (memberid     int not null primary key,
      name         varchar(30) not null,
      registered   date not null,
      unique(name));
INSERT INTO forum_members VALUES(1,'Harry','2017-03-08');
INSERT INTO forum_members VALUES(2,'Strangelove','2017-04-12');
INSERT INTO forum_members VALUES(3,'Lorelei','2017-05-09');
INSERT INTO forum_members VALUES(4,'Harry Lime','2017-05-28');
INSERT INTO forum_members VALUES(5,'Rick','2017-07-07');
INSERT INTO forum_members VALUES(6,'Darth Vader','2017-07-13');
INSERT INTO forum_members VALUES(7,'Jennifer','2017-08-31');
INSERT INTO forum_members VALUES(8,'Holly','2018-01-07');
INSERT INTO forum_members VALUES(9,'Vito','2018-02-06');
INSERT INTO forum_members VALUES(10,'Sally','2018-02-21');
CREATE TABLE forum_topics
     (topicid      int not null primary key,
      post_date    date not null,
      memberid     int not null,
      message      text not null,
      foreign key (memberid) references forum_members(memberid));
INSERT INTO forum_topics VALUES(1,'2018-03-12',7,'What do you think of 2001 A Space Odyssey?');
INSERT INTO forum_topics VALUES(2,'2018-03-12',1,'Wouldn''t you in Casablanca rather be with Humphrey Bogart than the other guy??');
INSERT INTO forum_topics VALUES(3,'2018-03-12',4,'Do you prefer Italian Renaissance or brotherly love and five hundred years of democracy and peace?');
CREATE TABLE forum_posts
     (topicid      int not null,
      postid       int not null,
      post_date    date not null,
      memberid     int not null,
      ancestry     varchar(1000),
      message      text not null,
      primary key (postid),
      foreign key (memberid) references forum_members(memberid),
      foreign key (topicid) references forum_topics(topicid));
INSERT INTO forum_posts VALUES(1,1723,'2018-03-12',8,NULL,'Kubrick''s best film');
INSERT INTO forum_posts VALUES(2,1725,'2018-03-12',10,NULL,'I don''t want to spend the rest of my life in Casablanca married to a man who runs a bar. I probably sound very snobbish to you but I don''t.');
INSERT INTO forum_posts VALUES(1,1727,'2018-03-12',3,NULL,'I didn''t understand anything');
INSERT INTO forum_posts VALUES(1,1732,'2018-03-12',6,'0000001723','Nothing beats Star Wars');
INSERT INTO forum_posts VALUES(1,1733,'2018-03-12',4,'00000017230000001732','Are you kidding?');
INSERT INTO forum_posts VALUES(2,1734,'2018-03-12',1,'0000001725','You''d rather be in a passionless marriage.');
INSERT INTO forum_posts VALUES(2,1741,'2018-03-12',10,'00000017250000001734','And be the first lady of Czechoslovakia.');
INSERT INTO forum_posts VALUES(1,1743,'2018-03-12',2,'0000001723','I prefer another one :-)');
INSERT INTO forum_posts VALUES(1,1747,'2018-03-12',9,'00000017230000001732','Darth, you''ll stop trolling if I ask you gently.');
CREATE TABLE films_francais
     (titre   varchar(100) not null,
      annee   int not null,
      primary key(titre, annee));
INSERT INTO films_francais VALUES('Les Enfants du Paradis',1945);
INSERT INTO films_francais VALUES('Pierrot le Fou',1965);
INSERT INTO films_francais VALUES('Les 400 coups',1959);
INSERT INTO films_francais VALUES('L''Atalante',1934);
INSERT INTO films_francais VALUES('Le Mépris',1963);
INSERT INTO films_francais VALUES('Mon Oncle',1958);
INSERT INTO films_francais VALUES('Les Yeux sans visage',1959);
INSERT INTO films_francais VALUES('Le Salaire de la Peur',1953);
INSERT INTO films_francais VALUES('L''Armée des Ombres',1969);
INSERT INTO films_francais VALUES('Les Tontons Flingueurs',1963);
INSERT INTO films_francais VALUES('Le Fabuleux Destin d''Amélie Poulain',2001);
CREATE TABLE alt_titles
       (titleid  integer not null primary key,
        movieid  int,
        title    varchar(250) not null,
        unique(movieid, title),
        foreign key (movieid) references movies(movieid)
            on delete cascade);
CREATE TABLE movie_title_ft_index2
       (title_word    varchar(50) not null,
        movieid       int not null,
        titleid       int default 1 not null,
        primary key(title_word, movieid, titleid),
        foreign key (movieid) references movies(movieid)
            on delete cascade,
        foreign key(titleid) references alt_titles(titleid));
COMMIT;
