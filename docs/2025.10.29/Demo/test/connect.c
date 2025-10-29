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

    /*
     * 用户在命令行上提供了conninfo字符串的值时使用该值
     * 否则环境变量或者所有其它连接参数
     * 都使用缺省值。
     */
    if (argc > 1)
        conninfo = argv[1];
    else
        conninfo = "dbname=postgres port=5432 host='127.0.0.1' user='omm' password='omm_1234";
    // conninfo = "dbname=postgres port=42121 host='10.44.133.171' application_name=test connect_timeout=5 sslmode=allow user='test' password='test_1234'";

    /* 连接数据库 */
    conn = PQconnectdb(conninfo);

    /* 检查后端连接成功建立 */
    if (PQstatus(conn) != CONNECTION_OK)
    {
        fprintf(stderr, "Connection to database failed: %s", PQerrorMessage(conn));
        exit_nicely(conn);
    }
    else
        printf("Connected!\n");

    /* 关闭数据库连接并清理 */
    PQfinish(conn);

    return 0;
}
