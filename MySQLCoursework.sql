-- Create table statements
CREATE TABLE book (
isbn CHAR(17) NOT NULL,
title VARCHAR(30) NOT NULL,
author VARCHAR(30) NOT NULL,
CONSTRAINT PK_isbn PRIMARY KEY (isbn));


CREATE TABLE copy (
`code` INT NOT NULL,
isbn CHAR(17) NOT NULL,
duration TINYINT,
CONSTRAINT CHK_Duration CHECK (duration IN(7, 14, 21)),
CONSTRAINT PK_Code PRIMARY KEY (`code`),
CONSTRAINT FK_isbn FOREIGN KEY (isbn) REFERENCES book(isbn) ON UPDATE CASCADE ON DELETE CASCADE);


CREATE TABLE student (
`no` INT NOT NULL,
`name` VARCHAR(30) NOT NULL,
school CHAR(3)NOT NULL,
embargo BIT(1) NOT NULL DEFAULT FALSE,
CONSTRAINT PK_no PRIMARY KEY (`no`));


CREATE TABLE loan (
`code` INT NOT NULL,
`no` INT NOT NULL,
taken DATE NOT NULL,
due DATE NOT NULL,
`return` DATE NULL,
CONSTRAINT PK_taken PRIMARY KEY (taken,student `no`, `code`),
CONSTRAINT FK_code FOREIGN KEY (`code`) REFERENCES copy(`code`) ON UPDATE CASCADE ON DELETE CASCADE,
CONSTRAINT FK_no FOREIGN KEY (`no`) REFERENCES student(`no`) ON UPDATE CASCADE ON DELETE CASCADE);


-- Create view statements
CREATE VIEW CMP_only
AS
SELECT `no`, `name`, school, embargo 
FROM student 
WHERE school = 'CMP'
WITH CHECK OPTION;

INSERT INTO CMP_only(`no`, `name`, school, embargo)
VALUES (3001, 'John', 'BUE', 0);


-- Create procedure statement
DELIMITER $$

CREATE PROCEDURE issue_new_loan(IN book_isbn CHAR(17), IN student_no INT)
	
BEGIN
		
DECLARE copy_codes INT; 
DECLARE Will_it_loan INT;
		
DECLARE issued BOOLEAN;
DECLARE complete BOOLEAN;
      
DECLARE due_date DATE;
    
DECLARE copy_duration TINYINT;
        
DECLARE embargo_status BIT(1) DEFAULT b'1';
        
DECLARE  copy_c CURSOR FOR
SELECT `code`
FROM copy 
WHERE isbn = book_isbn;
DECLARE CONTINUE HANDLER FOR NOT FOUND	
SET complete = TRUE;
	
OPEN copy_c;
        
SET embargo_status = (SELECT embargo 
FROM student
WHERE `no` = student_no);
SELECT embargo_status;
		
IF (embargo_status = b'1') THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'The student is currently under embargo!';		
END IF;	


SET issued = FALSE;
SET copy_codes = 0;
		
LoopDeLoop : LOOP
        
FETCH NEXT FROM copy_c INTO copy_codes;
            
IF(complete)THEN
LEAVE LoopDeLoop;
END IF;
            
SET Will_it_loan = (SELECT `code` FROM loan
WHERE (`code` = copy_codes) AND (`return` IS NULL));
		
IF(Will_it_loan IS NULL) THEN
			
SET copy_duration = (SELECT duration
FROM copy
WHERE `code` = copy_codes);
			
SET due_date = DATE_ADD(CURRENT_DATE, INTERVAL copy_duration DAY);
                
INSERT INTO loan (`code`, `no`, taken, due,`return`)
VALUES (copy_codes, student_no, CURRENT_DATE, due_date, null);
			
SET issued = TRUE;
		
LEAVE LoopDeLoop;
END IF;
		
END LOOP;
	
CLOSE copy_c;	
	
IF(issued = FALSE) THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'A copy of the book is not available';
END IF;

 END$$
DELIMITER ;


-- Create trigger statement 
CREATE TABLE audit (
`no` INT NOT NULL,
taken DATE NOT NULL,
due DATE NOT NULL,
`return` DATE NULL);

delimiter $$

CREATE TRIGGER Loan_Audit_Trail AFTER
UPDATE ON loan FOR EACH ROW

BEGIN 

IF(OLD.`return` IS NULL) AND (CURRENT_DATE() > OLD.due) THEN 
INSERT INTO audit (`no`, taken, due, `return`) 
VALUES (NEW.`no`, NEW.taken, NEW.due, NEW.`return`); 

END IF;
        
END$$
DELIMITER ;


-- Insert statements 
INSERT INTO book (isbn, title, author)
VALUES ('111-2-33-444444-5', 'Pro JavaFX', 'Dave Smith');

INSERT INTO book (isbn, title, author)
VALUES ('222-3-44-555555-6', 'Oracle Systems', 'Kate Roberts');

INSERT INTO book (isbn, title, author)
VALUES ('333-4-55-666666-7', 'Expert jQuery', 'Mike Smith');


INSERT INTO copy (`code`, isbn, duration)
VALUES ('1011','111-2-33-444444-5','21');

INSERT INTO copy (`code`, isbn, duration)
VALUES ('1012','111-2-33-444444-5','14');

INSERT INTO copy (`code`, isbn, duration)
VALUES ('1013','111-2-33-444444-5','7');

INSERT INTO copy (`code`, isbn, duration)
VALUES ('2011','222-3-44-555555-6','21');

INSERT INTO copy (`code`, isbn, duration)
VALUES ('3011','333-4-55-666666-7','7');

INSERT INTO copy (`code`, isbn, duration)
VALUES ('3012','333-4-55-666666-7','14');


INSERT INTO loan (`code`, `no`, taken, due, `return`)
VALUES ('1011','2002','2018.01.10','2018.01.31','2018.01.31');

INSERT INTO loan (`code`, `no`, taken, due, `return`)
VALUES ('1011',	'2002','2018.02.05','2018.02.26','2018.02.23');

INSERT INTO loan (`code`, `no`, taken, due, `return`)
VALUES ('1011','2003','2018.05.10','2018.05.31',NULL);

INSERT INTO loan (`code`, `no`, taken, due, `return`)
VALUES ('1013','2003','2017.03.02','2017.03.16','2017.03.10');

INSERT INTO loan (`code`, `no`, taken, due, `return`)
VALUES ('1013','2002','2017.08.02','2017.08.16','2017.08.16');

INSERT INTO loan (`code`, `no`, taken, due, `return`)
VALUES ('2011','2004','2016.02.01','2016.02.22','2016.02.20');

INSERT INTO loan (`code`, `no`, taken, due, `return`)
VALUES ('3011','2002','2018.07.03','2018.07.10',NULL);

INSERT INTO loan (`code`, `no`, taken, due, `return`)
VALUES ('3011','2005','2017.10.10','2017.10.17','2017.10.20');


INSERT INTO student (`no`, `name`, school, embargo)
VALUES ('2001','Mike','CMP',0);

INSERT INTO student (`no`, `name`, school, embargo)
VALUES ('2002','Andy','CMP',1);

INSERT INTO student (`no`, `name`, school, embargo)
VALUES ('2003','Sarah','ENG',0);

INSERT INTO student (`no`, `name`, school, embargo)
VALUES ('2004','Karen','ENG',1);

INSERT INTO student (`no`, `name`, school, embargo)
VALUES ('2005','Lucy','BUE',0);

-- Queries 
SELECT isbn, title, author
FROM book;

SELECT `no`, `name`, school 
FROM student 
ORDER BY school DESC;

SELECT isbn, title
FROM book
WHERE author LIKE '%Smith%';

SELECT MAX(due) AS 'Latest due date for any book'
From loan;

SELECT `no`
FROM loan
WHERE due =
(SELECT MAX(due) FROM loan);

SELECT `no`, `name`
FROM student
WHERE `no` = 
(SELECT `no`
FROM loan
WHERE due =
(SELECT MAX(due) FROM loan))

SELECT `no`, `code`, due
FROM loan
WHERE YEAR(taken) = YEAR(CURRENT_DATE) AND `return` IS null;

SELECT DISTINCT S.`no`, S.`name`, B.isbn, B.title
FROM student S INNER JOIN loan L
ON S.`no` = L.`no`
INNER JOIN copy C
ON L.`code` = C.code
INNER JOIN book B
ON C.isbn = B.isbn
WHERE C.duration = 7;

SELECT DISTINCT S.`no`, S.`name`
FROM student S INNER JOIN loan L
ON S.`no` = L.`no`
WHERE  L.due =
(SELECT MAX(due) FROM loan);

SELECT B.title, COUNT(B.title) AS 'Loan Frequency'
FROM book B INNER JOIN copy C
ON B.isbn = C.isbn
INNER JOIN loan L
ON C.code  =L.code
GROUP BY B.title;

SELECT B.title, COUNT(B.title) AS 'Loan Frequency'
FROM book B INNER JOIN copy C
ON B.isbn = C.isbn
INNER JOIN loan L
ON C.code  =L.code
GROUP BY B.title
HAVING COUNT(B.title) >= 2;


