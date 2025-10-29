#include <stdio.h>
#include <stdlib.h>
#include <libpq-fe.h>

static void
exit_nicely(PGconn *conn)
{
    PQfinish(conn);
    exit(1);
}

int main(int argc, char **argv)
{
    const char *conninfo;
    PGconn *conn;
    PGresult *res;

    if (argc > 1)
        conninfo = argv[1];
    else
        conninfo = "dbname=postgres port=5432 host='127.0.0.1' user='omm' password='omm_12345'";
    // conninfo = "dbname=postgres port=42121 host='10.44.133.171' application_name=test connect_timeout=5 sslmode=allow user='test' password='test_1234'";

    conn = PQconnectdb(conninfo);

    if (PQstatus(conn) != CONNECTION_OK)
    {
        fprintf(stderr, "Connection to database failed: %s", PQerrorMessage(conn));
        exit_nicely(conn);
    }
    else
        printf("Connected!\n");

    /* 插入 */
    res = PQexec(conn, "insert into customer_t1 values(0,'li')");
    res = PQexec(conn, "insert into customer_t1 values(1, 'zhang')");
    res = PQexec(conn, "insert into customer_t1 values(2, 'wang')");
    res = PQexec(conn, "insert into customer_t1 values(3, 'zhao')");
    res = PQexec(conn, "insert into customer_t1 values(4, 'sun')");
    res = PQexec(conn, "insert into customer_t1 values(5, 'liu')");
    res = PQexec(conn, "insert into customer_t1 values(6, 'chen')");
    res = PQexec(conn, "insert into customer_t1 values(7, 'gao')");
    res = PQexec(conn, "insert into customer_t1 values(8, 'lin')");
    res = PQexec(conn, "insert into customer_t1 values(9, 'xu')");
    res = PQexec(conn, "insert into customer_t1 values(10, 'huang')");
    if (PQresultStatus(res) != PGRES_COMMAND_OK)
    {
        fprintf(stderr, "INSERT command failed: %s", PQerrorMessage(conn));
        PQclear(res);
        exit_nicely(conn);
    }
    else
        printf("INSERT command executed successfully.\n");

    /* 关闭数据库连接并清理 */
    PQfinish(conn);

    return 0;
}
