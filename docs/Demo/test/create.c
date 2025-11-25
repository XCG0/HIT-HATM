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
    int nFields;
    int i, j;

    if (argc > 1)
        conninfo = argv[1];
    else
        conninfo = "dbname=postgres port=5432 host='127.0.0.1' user='omm' password='omm_1234'";
    // conninfo = "dbname=postgres port=42121 host='10.44.133.171' application_name=test connect_timeout=5 sslmode=allow user='test' password='test_1234'";

    conn = PQconnectdb(conninfo);

    if (PQstatus(conn) != CONNECTION_OK)
    {
        fprintf(stderr, "Connection to database failed: %s", PQerrorMessage(conn));
        exit_nicely(conn);
    }
    else
        printf("Connected!\n");

    /* 创建 */
    res = PQexec(conn, "CREATE TABLE customer_t1(c_customer_sk INTEGER, c_customer_name VARCHAR(32))");
    if (PQresultStatus(res) != PGRES_COMMAND_OK)
    {
        fprintf(stderr, "CREATE command failed: %s", PQerrorMessage(conn));
        PQclear(res);
        exit_nicely(conn);
    }
    else
        printf("CREATE command executed successfully.\n");

    /* 关闭数据库连接并清理 */
    PQfinish(conn);

    return 0;
}
