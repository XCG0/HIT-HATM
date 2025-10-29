#include <stdio.h>
#include <stdlib.h>
#include <libpq-fe.h>

void exit_with_error(PGconn *conn)
{
    fprintf(stderr, "Error: %s\n", PQerrorMessage(conn));
    PQfinish(conn);
    exit(EXIT_FAILURE);
}

int main()
{
    // 数据库连接参数
    const char *conninfo = "dbname=postgres port=5432 host='127.0.0.1' user='omm' password='omm_12345'";

    // 初始化数据库连接
    PGconn *conn = PQconnectdb(conninfo);

    // 检查连接状态
    if (PQstatus(conn) != CONNECTION_OK)
    {
        fprintf(stderr, "Connection to database failed: %s\n", PQerrorMessage(conn));
        PQfinish(conn);
        return EXIT_FAILURE;
    }
    else
        printf("Connected!\n");

    // 执行查询
    const char *query = "SELECT * FROM customer_t1";
    PGresult *res = PQexec(conn, query);

    // 检查查询结果状态
    if (PQresultStatus(res) != PGRES_TUPLES_OK)
    {
        fprintf(stderr, "Query failed: %s\n", PQerrorMessage(conn));
        PQclear(res);
        PQfinish(conn);
        return EXIT_FAILURE;
    }
    else
        printf("SELECT command executed successfully.\n");

    // 获取列数和行数
    int nFields = PQnfields(res);
    int nRows = PQntuples(res);

    // 打印表头
    for (int i = 0; i < nFields; i++)
    {
        printf("+-----------------");
    }
    printf("+\n|");
    for (int i = 0; i < nFields; i++)
    {
        printf(" %-16s|", PQfname(res, i));
    }
    printf("\n");
    for (int i = 0; i < nFields; i++)
    {
        printf("+-----------------");
    }
    printf("+\n");

    // 打印每一行数据
    for (int i = 0; i < nRows; i++)
    {
        printf("|");
        for (int j = 0; j < nFields; j++)
        {
            printf(" %-16s|", PQgetvalue(res, i, j));
        }
        printf("\n");
    }

    // 打印表格底部横线
    for (int i = 0; i < nFields; i++)
    {
        printf("+-----------------");
    }
    printf("+\n");

    // 释放资源并关闭连接
    PQclear(res);
    PQfinish(conn);

    return EXIT_SUCCESS;
}