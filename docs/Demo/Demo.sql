-- 创建表
CREATE TABLE IF NOT EXISTS student (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    age INT NOT NULL
);

-- 插入数据
INSERT INTO
    student (name, age)
VALUES ('Alice', 30),
    ('Bob', 25),
    ('Charlie', 35),
    ('David', 28),
    ('Eve', 22),
    ('Frank', 40),
    ('Grace', 27),
    ('Hank', 33),
    ('Ivy', 29),
    ('Jack', 31);

-- 查询数据
SELECT * FROM student;

-- 更新数据：将所有人的年龄加 1
UPDATE student SET age = age + 1;

-- 查询更新后的数据
SELECT * FROM student;

-- 删除表
DROP TABLE IF EXISTS student;