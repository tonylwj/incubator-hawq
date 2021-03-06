--
-- TRIGGERS
--

create table pkeys (pkey1 int4 not null, pkey2 text not null);
create table fkeys (fkey1 int4, fkey2 text, fkey3 int);
create table fkeys2 (fkey21 int4, fkey22 text, pkey23 int not null);

create index fkeys_i on fkeys (fkey1, fkey2);
create index fkeys2_i on fkeys2 (fkey21, fkey22);
create index fkeys2p_i on fkeys2 (pkey23);

insert into pkeys values (10, '1');
insert into pkeys values (20, '2');
insert into pkeys values (30, '3');
insert into pkeys values (40, '4');
insert into pkeys values (50, '5');
insert into pkeys values (60, '6');
create unique index pkeys_i on pkeys (pkey1, pkey2);

--
-- For fkeys:
-- 	(fkey1, fkey2)	--> pkeys (pkey1, pkey2)
-- 	(fkey3)		--> fkeys2 (pkey23)
--
create trigger check_fkeys_pkey_exist 
	before insert or update on fkeys 
	for each row 
	execute procedure 
	check_primary_key ('fkey1', 'fkey2', 'pkeys', 'pkey1', 'pkey2');

create trigger check_fkeys_pkey2_exist 
	before insert or update on fkeys 
	for each row 
	execute procedure check_primary_key ('fkey3', 'fkeys2', 'pkey23');

--
-- For fkeys2:
-- 	(fkey21, fkey22)	--> pkeys (pkey1, pkey2)
--
create trigger check_fkeys2_pkey_exist 
	before insert or update on fkeys2 
	for each row 
	execute procedure 
	check_primary_key ('fkey21', 'fkey22', 'pkeys', 'pkey1', 'pkey2');

-- Test comments
COMMENT ON TRIGGER check_fkeys2_pkey_bad ON fkeys2 IS 'wrong';
COMMENT ON TRIGGER check_fkeys2_pkey_exist ON fkeys2 IS 'right';
COMMENT ON TRIGGER check_fkeys2_pkey_exist ON fkeys2 IS NULL;

--
-- For pkeys:
-- 	ON DELETE/UPDATE (pkey1, pkey2) CASCADE:
-- 		fkeys (fkey1, fkey2) and fkeys2 (fkey21, fkey22)
--
create trigger check_pkeys_fkey_cascade
	before delete or update on pkeys 
	for each row 
	execute procedure 
	check_foreign_key (2, 'cascade', 'pkey1', 'pkey2', 
	'fkeys', 'fkey1', 'fkey2', 'fkeys2', 'fkey21', 'fkey22');

--
-- For fkeys2:
-- 	ON DELETE/UPDATE (pkey23) RESTRICT:
-- 		fkeys (fkey3)
--
create trigger check_fkeys2_fkey_restrict 
	before delete or update on fkeys2
	for each row 
	execute procedure check_foreign_key (1, 'restrict', 'pkey23', 'fkeys', 'fkey3');

insert into fkeys2 values (10, '1', 1);
insert into fkeys2 values (30, '3', 2);
insert into fkeys2 values (40, '4', 5);
insert into fkeys2 values (50, '5', 3);
-- no key in pkeys
insert into fkeys2 values (70, '5', 3);

insert into fkeys values (10, '1', 2);
insert into fkeys values (30, '3', 3);
insert into fkeys values (40, '4', 2);
insert into fkeys values (50, '5', 2);
-- no key in pkeys
insert into fkeys values (70, '5', 1);
-- no key in fkeys2
insert into fkeys values (60, '6', 4);

delete from pkeys where pkey1 = 30 and pkey2 = '3';
delete from pkeys where pkey1 = 40 and pkey2 = '4';
update pkeys set pkey1 = 7, pkey2 = '70' where pkey1 = 50 and pkey2 = '5';
update pkeys set pkey1 = 7, pkey2 = '70' where pkey1 = 10 and pkey2 = '1';

DROP TABLE pkeys;
DROP TABLE fkeys;
DROP TABLE fkeys2;

-- -- I've disabled the funny_dup17 test because the new semantics
-- -- of AFTER ROW triggers, which get now fired at the end of a
-- -- query always, cause funny_dup17 to enter an endless loop.
-- --
-- --      Jan
--
-- create table dup17 (x int4);
-- 
-- create trigger dup17_before 
-- 	before insert on dup17
-- 	for each row 
-- 	execute procedure 
-- 	funny_dup17 ()
-- ;
-- 
-- insert into dup17 values (17);
-- select count(*) from dup17;
-- insert into dup17 values (17);
-- select count(*) from dup17;
-- 
-- drop trigger dup17_before on dup17;
-- 
-- create trigger dup17_after
-- 	after insert on dup17
-- 	for each row 
-- 	execute procedure 
-- 	funny_dup17 ()
-- ;
-- insert into dup17 values (13);
-- select count(*) from dup17 where x = 13;
-- insert into dup17 values (13);
-- select count(*) from dup17 where x = 13;
-- 
-- DROP TABLE dup17;

create sequence ttdummy_seq increment 10 start 0 minvalue 0;

create table tttest (
	price_id	int4, 
	price_val	int4, 
	price_on	int4,
	price_off	int4 default 999999
);

create trigger ttdummy 
	before delete or update on tttest
	for each row 
	execute procedure 
	ttdummy (price_on, price_off);

create trigger ttserial 
	before insert or update on tttest
	for each row 
	execute procedure 
	autoinc (price_on, ttdummy_seq);

insert into tttest values (1, 1, null);
insert into tttest values (2, 2, null);
insert into tttest values (3, 3, 0);

select * from tttest;
delete from tttest where price_id = 2;
select * from tttest;
-- what do we see ?

-- get current prices
select * from tttest where price_off = 999999;

-- change price for price_id == 3
update tttest set price_val = 30 where price_id = 3;
select * from tttest;

-- now we want to change pric_id in ALL tuples
-- this gets us not what we need
update tttest set price_id = 5 where price_id = 3;
select * from tttest;

-- restore data as before last update:
select set_ttdummy(0);
delete from tttest where price_id = 5;
update tttest set price_off = 999999 where price_val = 30;
select * from tttest;

-- and try change price_id now!
update tttest set price_id = 5 where price_id = 3;
select * from tttest;
-- isn't it what we need ?

select set_ttdummy(1);

-- we want to correct some "date"
update tttest set price_on = -1 where price_id = 1;
-- but this doesn't work

-- try in this way
select set_ttdummy(0);
update tttest set price_on = -1 where price_id = 1;
select * from tttest;
-- isn't it what we need ?

-- get price for price_id == 5 as it was @ "date" 35
select * from tttest where price_on <= 35 and price_off > 35 and price_id = 5;

drop table tttest;
drop sequence ttdummy_seq;

--
-- tests for per-statement triggers
--

CREATE TABLE log_table (tstamp timestamp default timeofday()::timestamp);

CREATE TABLE main_table (a int, b int);

COPY main_table (a,b) FROM stdin;
5	10
20	20
30	10
50	35
80	15
\.

CREATE FUNCTION trigger_func() RETURNS trigger LANGUAGE plpgsql AS '
BEGIN
	RAISE NOTICE ''trigger_func() called: action = %, when = %, level = %'', TG_OP, TG_WHEN, TG_LEVEL;
	RETURN NULL;
END;';

CREATE TRIGGER before_ins_stmt_trig BEFORE INSERT ON main_table
FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();

CREATE TRIGGER after_ins_stmt_trig AFTER INSERT ON main_table
FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();

--
-- if neither 'FOR EACH ROW' nor 'FOR EACH STATEMENT' was specified,
-- CREATE TRIGGER should default to 'FOR EACH STATEMENT'
--
CREATE TRIGGER before_upd_stmt_trig AFTER UPDATE ON main_table
EXECUTE PROCEDURE trigger_func();

CREATE TRIGGER before_upd_row_trig AFTER UPDATE ON main_table
FOR EACH ROW EXECUTE PROCEDURE trigger_func();

INSERT INTO main_table DEFAULT VALUES;

UPDATE main_table SET a = a + 1 WHERE b < 30;
-- UPDATE that effects zero rows should still call per-statement trigger
UPDATE main_table SET a = a + 2 WHERE b > 100;

-- COPY should fire per-row and per-statement INSERT triggers
COPY main_table (a, b) FROM stdin;
30	40
50	60
\.

SELECT * FROM main_table ORDER BY a, b;

-- Test enable/disable triggers

create table trigtest (i serial primary key);
-- test that disabling RI triggers works
create table trigtest2 (i int references trigtest(i) on delete cascade);

create function trigtest() returns trigger as $$
begin
	raise notice '% % % %', TG_RELNAME, TG_OP, TG_WHEN, TG_LEVEL;
	return new;
end;$$ language plpgsql immutable;

create trigger trigtest_b_row_tg before insert or update or delete on trigtest
for each row execute procedure trigtest();
create trigger trigtest_a_row_tg after insert or update or delete on trigtest
for each row execute procedure trigtest();
create trigger trigtest_b_stmt_tg before insert or update or delete on trigtest
for each statement execute procedure trigtest();
create trigger trigtest_a_stmt_tg after insert or update or delete on trigtest
for each statement execute procedure trigtest();

insert into trigtest default values;
alter table trigtest disable trigger trigtest_b_row_tg;
insert into trigtest default values;
alter table trigtest disable trigger user;
insert into trigtest default values;
alter table trigtest enable trigger trigtest_a_stmt_tg;
insert into trigtest default values;
insert into trigtest2 values(1);
insert into trigtest2 values(2);
delete from trigtest where i=2;
select * from trigtest2;
alter table trigtest disable trigger all;
delete from trigtest where i=1;
select * from trigtest2;
-- ensure we still insert, even when all triggers are disabled
insert into trigtest default values;
select *  from trigtest;
drop table trigtest2;
drop table trigtest;


-- dump trigger data
CREATE TABLE trigger_test (
        i int,
        v varchar
);

CREATE OR REPLACE FUNCTION trigger_data()  RETURNS trigger 
LANGUAGE plpgsql AS $$

declare

	argstr text;
	relid text;

begin

	relid := TG_relid::regclass;

	-- plpgsql can't discover its trigger data in a hash like perl and python
	-- can, or by a sort of reflection like tcl can, 
	-- so we have to hard code the names.
	raise NOTICE 'TG_NAME: %', TG_name;
	raise NOTICE 'TG_WHEN: %', TG_when;
	raise NOTICE 'TG_LEVEL: %', TG_level;
	raise NOTICE 'TG_OP: %', TG_op;
	raise NOTICE 'TG_RELID::regclass: %', relid;
	raise NOTICE 'TG_RELNAME: %', TG_relname;
	raise NOTICE 'TG_TABLE_NAME: %', TG_table_name;
	raise NOTICE 'TG_TABLE_SCHEMA: %', TG_table_schema;
	raise NOTICE 'TG_NARGS: %', TG_nargs;

	argstr := '[';
	for i in 0 .. TG_nargs - 1 loop
		if i > 0 then
			argstr := argstr || ', ';
		end if;
		argstr := argstr || TG_argv[i];
	end loop;
	argstr := argstr || ']';
	raise NOTICE 'TG_ARGV: %', argstr;

	if TG_OP != 'INSERT' then
		raise NOTICE 'OLD: %', OLD;
	end if;

	if TG_OP != 'DELETE' then
		raise NOTICE 'NEW: %', NEW;
	end if;

	if TG_OP = 'DELETE' then
		return OLD;
	else
		return NEW;
	end if;

end;
$$;

CREATE TRIGGER show_trigger_data_trig 
BEFORE INSERT OR UPDATE OR DELETE ON trigger_test
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

insert into trigger_test values(1,'insert');
update trigger_test set v = 'update' where i = 1;
delete from trigger_test;
      
DROP TRIGGER show_trigger_data_trig on trigger_test;
      
DROP FUNCTION trigger_data();

DROP TABLE trigger_test;

--
-- Test use of row comparisons on OLD/NEW
--

CREATE TABLE trigger_test (f1 int, f2 text, f3 text);

-- this is the obvious (and wrong...) way to compare rows
CREATE FUNCTION mytrigger() RETURNS trigger LANGUAGE plpgsql as $$
begin
	if row(old.*) = row(new.*) then
		raise notice 'row % not changed', new.f1;
	else
		raise notice 'row % changed', new.f1;
	end if;
	return new;
end$$;

CREATE TRIGGER t
BEFORE UPDATE ON trigger_test
FOR EACH ROW EXECUTE PROCEDURE mytrigger();

INSERT INTO trigger_test VALUES(1, 'foo', 'bar');
INSERT INTO trigger_test VALUES(2, 'baz', 'quux');

UPDATE trigger_test SET f3 = 'bar';
UPDATE trigger_test SET f3 = NULL;
-- this demonstrates that the above isn't really working as desired:
UPDATE trigger_test SET f3 = NULL;

-- the right way when considering nulls is
CREATE OR REPLACE FUNCTION mytrigger() RETURNS trigger LANGUAGE plpgsql as $$
begin
	if row(old.*) is distinct from row(new.*) then
		raise notice 'row % changed', new.f1;
	else
		raise notice 'row % not changed', new.f1;
	end if;
	return new;
end$$;

UPDATE trigger_test SET f3 = 'bar';
UPDATE trigger_test SET f3 = NULL;
UPDATE trigger_test SET f3 = NULL;

DROP TABLE trigger_test;

DROP FUNCTION mytrigger();
