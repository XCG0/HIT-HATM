#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libpq-fe.h>

#define TABLE_NAME "student" // 定义表名

static void exit_nicely(PGconn *conn)
{
    PQfinish(conn);
    exit(1);
}

/* 连接数据库 */
PGconn *connect_to_db(const char *conninfo)
{
    PGconn *conn = PQconnectdb(conninfo);
    if (PQstatus(conn) != CONNECTION_OK)
    {
        fprintf(stderr, "Connection to database failed: %s", PQerrorMessage(conn));
        exit_nicely(conn);
    }
    printf("Connected to database successfully.\n");
    return conn;
}

/* 创建表 */
void create_table(PGconn *conn)
{
    char create_query[256];
    snprintf(create_query, sizeof(create_query),
             "CREATE TABLE IF NOT EXISTS %s (id SERIAL PRIMARY KEY, name VARCHAR(50), age INT);",
             TABLE_NAME);

    PGresult *res = PQexec(conn, create_query);

    if (PQresultStatus(res) != PGRES_COMMAND_OK)
    {
        fprintf(stderr, "CREATE TABLE failed: %s", PQerrorMessage(conn));
        PQclear(res);
        exit_nicely(conn);
    }

    printf("Table '%s' created successfully (if it did not already exist).\n", TABLE_NAME);
    PQclear(res);
}

/* 插入数据 */
void insert_data(PGconn *conn)
{
    FILE *file = fopen("demo.csv", "r");
    if (!file)
    {
        fprintf(stderr, "Failed to open demo.csv\n");
        exit(EXIT_FAILURE);
    }

    char line[256];
    char insert_query[1024] = {0};
    snprintf(insert_query, sizeof(insert_query), "INSERT INTO %s (name, age) VALUES ", TABLE_NAME);

    int first = 1; // 标记是否是第一条数据
    while (fgets(line, sizeof(line), file))
    {
        char name[128];
        int age;

        // 解析 CSV 行，假设格式为 "name,age"
        if (sscanf(line, "%127[^,],%d", name, &age) == 2)
        {
            if (!first)
                strncat(insert_query, ", ", sizeof(insert_query) - strlen(insert_query) - 1);
            first = 0;

            char value[256];
            snprintf(value, sizeof(value), "('%s', %d)", name, age);
            strncat(insert_query, value, sizeof(insert_query) - strlen(insert_query) - 1);
        }
    }
    fclose(file);

    // 执行插入查询
    PGresult *res = PQexec(conn, insert_query);
    if (PQresultStatus(res) != PGRES_COMMAND_OK)
    {
        fprintf(stderr, "INSERT failed: %s", PQerrorMessage(conn));
        PQclear(res);
        exit(EXIT_FAILURE);
    }

    printf("Data inserted successfully into table '%s' from 'demo.csv'.\n", TABLE_NAME);
    PQclear(res);
}

/* 查询数据 */
void select_data(PGconn *conn)
{
    char select_query[256];
    snprintf(select_query, sizeof(select_query), "SELECT * FROM %s;", TABLE_NAME);

    PGresult *res = PQexec(conn, select_query);

    if (PQresultStatus(res) != PGRES_TUPLES_OK)
    {
        fprintf(stderr, "SELECT failed: %s", PQerrorMessage(conn));
        PQclear(res);
        exit_nicely(conn);
    }

    int nFields = PQnfields(res);
    int nRows = PQntuples(res);

    // 打印表头
    for (int i = 0; i < nFields; i++)
        printf("+-----------------");
    printf("+\n|");
    for (int i = 0; i < nFields; i++)
        printf(" %-16s|", PQfname(res, i));
    printf("\n");
    for (int i = 0; i < nFields; i++)
        printf("+-----------------");
    printf("+\n");

    // 打印每一行数据
    for (int i = 0; i < nRows; i++)
    {
        printf("|");
        for (int j = 0; j < nFields; j++)
            printf(" %-16s|", PQgetvalue(res, i, j));
        printf("\n");
    }

    // 打印表格底部横线
    for (int i = 0; i < nFields; i++)
        printf("+-----------------");
    printf("+\n");

    PQclear(res);
}

/* 更新数据 */
void update_data(PGconn *conn)
{
    char update_query[256];
    snprintf(update_query, sizeof(update_query),
             "UPDATE %s SET age = age + 1;",
             TABLE_NAME);

    PGresult *res = PQexec(conn, update_query);

    if (PQresultStatus(res) != PGRES_COMMAND_OK)
    {
        fprintf(stderr, "UPDATE failed: %s", PQerrorMessage(conn));
        PQclear(res);
        exit_nicely(conn);
    }

    printf("Data updated successfully in table '%s'.\n", TABLE_NAME);
    PQclear(res);
}

/* 删除表 */
void drop_table(PGconn *conn)
{
    char drop_query[256];
    snprintf(drop_query, sizeof(drop_query),
             "DROP TABLE IF EXISTS %s;",
             TABLE_NAME);

    PGresult *res = PQexec(conn, drop_query);

    if (PQresultStatus(res) != PGRES_COMMAND_OK)
    {
        fprintf(stderr, "DROP TABLE failed: %s", PQerrorMessage(conn));
        PQclear(res);
        exit_nicely(conn);
    }

    printf("Table '%s' dropped successfully (if it existed).\n", TABLE_NAME);
    PQclear(res);
}

int main()
{
    const char *conninfo = "dbname=postgres port=5432 host='127.0.0.1' user='omm' password='omm_12345'";
    PGconn *conn = PQconnectdb(conninfo);

    if (PQstatus(conn) != CONNECTION_OK)
    {
        fprintf(stderr, "Connection to database failed: %s", PQerrorMessage(conn));
        exit_nicely(conn);
    }

    printf("Droping table '%s':\n", TABLE_NAME);
    drop_table(conn);

    printf("\nCreating table '%s':\n", TABLE_NAME);
    create_table(conn);

    printf("\nInserting data into table '%s':\n", TABLE_NAME);
    insert_data(conn);

    printf("\nSelecting data from table '%s':\n", TABLE_NAME);
    select_data(conn);

    printf("\nUpdating data in table (All members age+1) '%s':\n", TABLE_NAME);
    update_data(conn);

    printf("\nAfter update:\n");
    select_data(conn);

    PQfinish(conn);
    return 0;
}