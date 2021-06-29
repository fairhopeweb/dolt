#!/usr/bin/env bats
load $BATS_TEST_DIRNAME/helper/common.bash

setup() {
    setup_common
}

teardown() {
    assert_feature_version
    teardown_common
}

@test "constraint-violations: ancestor contains fk, main parent remove, other child add, restrict" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1));
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "DELETE FROM parent WHERE pk = 20;"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql -q "INSERT INTO child VALUES (2, 2)"
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor contains fk, main child add, other parent remove, restrict" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1));
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "INSERT INTO child VALUES (2, 2)"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql -q "DELETE FROM parent WHERE pk = 20;"
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor contains fk, main parent add and remove, other child add and remove, restrict" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1));
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
DELETE FROM parent WHERE pk = 20;
INSERT INTO parent VALUES (30, 3);
SQL
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
DELETE FROM CHILD WHERE pk = 1;
INSERT INTO child VALUES (2,2), (3, 2);
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,2" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "$output" =~ "foreign key,3,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "$output" =~ "30,3" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor contains fk, main parent illegal remove, restrict" {
    # We ignore intentional violations on our parent
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1));
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM parent WHERE pk = 20;
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "MC2"
    dolt checkout other
    dolt sql -q "INSERT INTO child VALUES (3, 2)"
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,3,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,2" ]] || false
    [[ "${#lines[@]}" = "4" ]] || false
}

@test "constraint-violations: ancestor contains fk, other child illegal add, restrict" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1));
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
DELETE FROM child WHERE pk = 1;
DELETE FROM parent WHERE pk = 10;
SQL
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
SET FOREIGN_KEY_CHECKS = 0;
INSERT INTO child VALUES (3, 3);
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,3,3,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "20,2" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,3" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor contains fk, other parent illegal remove, restrict" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1));
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "INSERT INTO child VALUES (3, 2)"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM parent WHERE pk = 20;
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,2" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "$output" =~ "foreign key,3,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,2" ]] || false
    [[ "${#lines[@]}" = "4" ]] || false
}

@test "constraint-violations: ancestor contains fk, main parent remove, other child add, cascade" {
    # Parent change is on our branch so reference option is not applied
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE CASCADE);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "DELETE FROM parent WHERE pk = 20;"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql -q "INSERT INTO child VALUES (2, 2)"
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor contains fk, main child add, other parent remove, cascade" {
    # Parent change is on other branch so reference option is applied
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE CASCADE);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "INSERT INTO child VALUES (2, 2)"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql -q "DELETE FROM parent WHERE pk = 20;"
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
}

@test "constraint-violations: ancestor contains fk, main parent add and remove, other child add and remove, cascade" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE CASCADE);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
DELETE FROM parent WHERE pk = 20;
INSERT INTO parent VALUES (30, 3);
SQL
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
DELETE FROM CHILD WHERE pk = 1;
INSERT INTO child VALUES (2,2), (3, 2);
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,2" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "$output" =~ "foreign key,3,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "$output" =~ "30,3" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor contains fk, main parent illegal remove, cascade" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE CASCADE);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM parent WHERE pk = 20;
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "MC2"
    dolt checkout other
    dolt sql -q "INSERT INTO child VALUES (3, 2)"
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,3,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,2" ]] || false
    [[ "${#lines[@]}" = "4" ]] || false
}

@test "constraint-violations: ancestor contains fk, other child illegal add, cascade" {
    # Parent change is on our branch so reference option is not applied
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE CASCADE);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
DELETE FROM child WHERE pk = 1;
DELETE FROM parent WHERE pk = 10;
SQL
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
SET FOREIGN_KEY_CHECKS = 0;
INSERT INTO child VALUES (3, 3);
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,3,3,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "20,2" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,3" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor contains fk, other parent illegal remove, cascade" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE CASCADE);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "INSERT INTO child VALUES (3, 2)"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM parent WHERE pk = 20;
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
}

@test "constraint-violations: ancestor contains fk, main parent remove, other child add, set null" {
    # Parent change is on our branch so reference option is not applied
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE SET NULL);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "DELETE FROM parent WHERE pk = 20;"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql -q "INSERT INTO child VALUES (2, 2)"
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor contains fk, main child add, other parent remove, set null" {
    # Parent change is on other branch so reference option is applied
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE SET NULL);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "INSERT INTO child VALUES (2, 2)"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql -q "DELETE FROM parent WHERE pk = 20;"
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2," ]] || false
    [[ ! "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor contains fk, main parent add and remove, other child add and remove, set null" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE SET NULL);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
DELETE FROM parent WHERE pk = 20;
INSERT INTO parent VALUES (30, 3);
SQL
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
DELETE FROM CHILD WHERE pk = 1;
INSERT INTO child VALUES (2,2), (3, 2);
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,2" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "$output" =~ "foreign key,3,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "$output" =~ "30,3" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor contains fk, main parent illegal remove, set null" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE SET NULL);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM parent WHERE pk = 20;
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "MC2"
    dolt checkout other
    dolt sql -q "INSERT INTO child VALUES (3, 2)"
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,3,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,2" ]] || false
    [[ "${#lines[@]}" = "4" ]] || false
}

@test "constraint-violations: ancestor contains fk, other child illegal add, set null" {
    # Parent change is on our branch so reference option is not applied
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE SET NULL);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
DELETE FROM child WHERE pk = 1;
DELETE FROM parent WHERE pk = 10;
SQL
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
SET FOREIGN_KEY_CHECKS = 0;
INSERT INTO child VALUES (3, 3);
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,3,3,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "20,2" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,3" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor contains fk, other parent illegal remove, set null" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE SET NULL);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "INSERT INTO child VALUES (3, 2)"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM parent WHERE pk = 20;
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2," ]] || false
    [[ "$output" =~ "3," ]] || false
    [[ ! "$output" =~ "2,2" ]] || false
    [[ ! "$output" =~ "3,2" ]] || false
    [[ "${#lines[@]}" = "4" ]] || false
}

@test "constraint-violations: ancestor contains fk, main parent remove with backup, other child add, restrict" {
    # Other parent rows satisfy the foreign key so no violation is recorded
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1));
INSERT INTO parent VALUES (10, 1), (20, 2), (30, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "DELETE FROM parent WHERE pk = 20;"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql -q "INSERT INTO child VALUES (2, 2)"
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "$output" =~ "30,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor contains fk, main child add, other parent remove with backup, restrict" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1));
INSERT INTO parent VALUES (10, 1), (20, 2), (30, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "INSERT INTO child VALUES (2, 2)"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql -q "DELETE FROM parent WHERE pk = 20;"
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "$output" =~ "30,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing fk, main parent remove, other child add, restrict" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "DELETE FROM parent WHERE pk = 20;"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1);
INSERT INTO child VALUES (2, 2);
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing fk, main child add, other parent remove, restrict" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "INSERT INTO child VALUES (2, 2)"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1);
DELETE FROM parent WHERE pk = 20;
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing fk, main parent add and remove, other child add and remove, restrict" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
DELETE FROM parent WHERE pk = 20;
INSERT INTO parent VALUES (30, 3);
SQL
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1);
DELETE FROM CHILD WHERE pk = 1;
INSERT INTO child VALUES (2,2), (3, 2);
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,2" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "$output" =~ "foreign key,3,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "$output" =~ "30,3" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing fk, main parent illegal remove, restrict" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM parent WHERE pk = 20;
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "MC2"
    dolt checkout other
dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1);
INSERT INTO child VALUES (3, 2);
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,3,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,2" ]] || false
    [[ "${#lines[@]}" = "4" ]] || false
}

@test "constraint-violations: ancestor missing fk, other child illegal add, restrict" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
DELETE FROM child WHERE pk = 1;
DELETE FROM parent WHERE pk = 10;
SQL
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1);
SET FOREIGN_KEY_CHECKS = 0;
INSERT INTO child VALUES (3, 3);
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,3,3,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "20,2" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,3" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing fk, other parent illegal remove, restrict" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "INSERT INTO child VALUES (3, 2)"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1);
SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM parent WHERE pk = 20;
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,2" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "$output" =~ "foreign key,3,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,2" ]] || false
    [[ "${#lines[@]}" = "4" ]] || false
}

@test "constraint-violations: ancestor missing fk, main parent remove, other child add, cascade" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "DELETE FROM parent WHERE pk = 20;"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE CASCADE;
INSERT INTO child VALUES (2, 2);
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing fk, main child add, other parent remove, cascade" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "INSERT INTO child VALUES (2, 2)"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE CASCADE;
DELETE FROM parent WHERE pk = 20;
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
}

@test "constraint-violations: ancestor missing fk, main parent add and remove, other child add and remove, cascade" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
DELETE FROM parent WHERE pk = 20;
INSERT INTO parent VALUES (30, 3);
SQL
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE CASCADE;
DELETE FROM CHILD WHERE pk = 1;
INSERT INTO child VALUES (2,2), (3, 2);
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,2" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "$output" =~ "foreign key,3,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "$output" =~ "30,3" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing fk, main parent illegal remove, cascade" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM parent WHERE pk = 20;
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE CASCADE;
INSERT INTO child VALUES (3, 2);
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,3,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,2" ]] || false
    [[ "${#lines[@]}" = "4" ]] || false
}

@test "constraint-violations: ancestor missing fk, other child illegal add, cascade" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
DELETE FROM child WHERE pk = 1;
DELETE FROM parent WHERE pk = 10;
SQL
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE CASCADE;
SET FOREIGN_KEY_CHECKS = 0;
INSERT INTO child VALUES (3, 3);
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,3,3,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "20,2" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,3" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing fk, other parent illegal remove, cascade" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "INSERT INTO child VALUES (3, 2)"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE CASCADE;
SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM parent WHERE pk = 20;
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
}

@test "constraint-violations: ancestor missing fk, main parent remove, other child add, set null" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "DELETE FROM parent WHERE pk = 20;"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE SET NULL;
INSERT INTO child VALUES (2, 2);
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing fk, main child add, other parent remove, set null" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "INSERT INTO child VALUES (2, 2)"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE SET NULL;
DELETE FROM parent WHERE pk = 20;
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2," ]] || false
    [[ ! "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing fk, main parent add and remove, other child add and remove, set null" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
DELETE FROM parent WHERE pk = 20;
INSERT INTO parent VALUES (30, 3);
SQL
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE SET NULL;
DELETE FROM CHILD WHERE pk = 1;
INSERT INTO child VALUES (2,2), (3, 2);
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,2" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "$output" =~ "foreign key,3,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "$output" =~ "30,3" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing fk, main parent illegal remove, set null" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM parent WHERE pk = 20;
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE SET NULL;
INSERT INTO child VALUES (3, 2);
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,3,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,2" ]] || false
    [[ "${#lines[@]}" = "4" ]] || false
}

@test "constraint-violations: ancestor missing fk, other child illegal add, set null" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql <<"SQL"
DELETE FROM child WHERE pk = 1;
DELETE FROM parent WHERE pk = 10;
SQL
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE SET NULL;
SET FOREIGN_KEY_CHECKS = 0;
INSERT INTO child VALUES (3, 3);
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,3,3,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "20,2" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "$output" =~ "3,3" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing fk, other parent illegal remove, set null" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO parent VALUES (10, 1), (20, 2);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "INSERT INTO child VALUES (3, 2)"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE SET NULL;
SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM parent WHERE pk = 20;
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2," ]] || false
    [[ "$output" =~ "3," ]] || false
    [[ ! "$output" =~ "2,2" ]] || false
    [[ ! "$output" =~ "3,2" ]] || false
    [[ "${#lines[@]}" = "4" ]] || false
}

@test "constraint-violations: ancestor missing parent, main child add, restrict" {
    dolt sql <<"SQL"
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "INSERT INTO child VALUES (2, 2)"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
INSERT INTO parent VALUES (10, 1);
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1);
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing parent, main child add, cascade" {
    dolt sql <<"SQL"
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "INSERT INTO child VALUES (2, 2)"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
INSERT INTO parent VALUES (10, 1);
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE CASCADE;
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing parent, main child add, set null" {
    dolt sql <<"SQL"
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO child VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "INSERT INTO child VALUES (2, 2)"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
INSERT INTO parent VALUES (10, 1);
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE SET NULL;
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing child, main parent remove, restrict" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
INSERT INTO parent VALUES (10, 1), (20, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "DELETE FROM parent WHERE pk = 20;"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1));
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing child, main parent remove, cascade" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
INSERT INTO parent VALUES (10, 1), (20, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "DELETE FROM parent WHERE pk = 20;"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE CASCADE);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing child, main parent remove, set null" {
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
INSERT INTO parent VALUES (10, 1), (20, 2);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "DELETE FROM parent WHERE pk = 20;"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1) ON DELETE SET NULL);
INSERT INTO child VALUES (1, 1), (2, 2);
SQL
    dolt add -A
    dolt commit -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "$output" =~ "child,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "$output" =~ "foreign key,2,2,fk_name" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}

@test "constraint-violations: ancestor missing both, other illegal operations, restrict" {
    dolt sql <<"SQL"
CREATE TABLE unrelated (pk BIGINT PRIMARY KEY, v1 BIGINT);
INSERT INTO unrelated VALUES (1, 1);
SQL
    dolt add -A
    dolt commit -m "MC1"
    dolt branch other
    dolt sql -q "INSERT INTO unrelated VALUES (2, 2)"
    dolt add -A
    dolt commit -m "MC2"
    dolt checkout other
    dolt sql <<"SQL"
CREATE TABLE parent (pk BIGINT PRIMARY KEY, v1 BIGINT, INDEX(v1));
CREATE TABLE child (pk BIGINT PRIMARY KEY, v1 BIGINT, CONSTRAINT fk_name FOREIGN KEY (v1) REFERENCES parent (v1));
INSERT INTO parent VALUES (10, 1);
SET FOREIGN_KEY_CHECKS = 0;
INSERT INTO child VALUES (1, 1), (2, 2);
SET FOREIGN_KEY_CHECKS = 1;
SQL
    dolt add -A
    dolt commit --force -m "OC1"
    dolt checkout master
    dolt merge other

    run dolt sql -q "SELECT * FROM dolt_constraint_violations" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "table,num_violations" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM dolt_constraint_violations_child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "violation_type,pk,v1,violation_info" ]] || false
    [[ "${#lines[@]}" = "1" ]] || false
    run dolt sql -q "SELECT * FROM parent" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "10,1" ]] || false
    [[ "${#lines[@]}" = "2" ]] || false
    run dolt sql -q "SELECT * FROM child" -r=csv
    [ "$status" -eq "0" ]
    [[ "$output" =~ "pk,v1" ]] || false
    [[ "$output" =~ "1,1" ]] || false
    [[ "$output" =~ "2,2" ]] || false
    [[ "${#lines[@]}" = "3" ]] || false
}
