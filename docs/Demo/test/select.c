#include <stdio.h>
#include <stdlib.h>
#include <libpq-fe.h>
#include <stdint.h>
#include <arpa/inet.h> // 添加此行以声明 htonl 和 ntohl

static void
exit_nicely(PGconn *conn)
{
    PQfinish(conn);
    exit(1);
}

static void
show_binary_results(PGresult *res)
{
    int i;
    int i_fnum,
        t_fnum;

    /* 使用 PQfnumber 来避免对结果中的字段顺序进行假设 */
    i_fnum = PQfnumber(res, "i");
    t_fnum = PQfnumber(res, "t");

    for (i = 0; i < PQntuples(res); i++)
    {
        char *iptr;
        char *tptr;
        int ival;

        /* 获取字段值（忽略可能为空的可能） */
        iptr = PQgetvalue(res, i, i_fnum);
        tptr = PQgetvalue(res, i, t_fnum);

        /*
         * INT4 的二进制表现形式是网络字节序
         * 建议转换成本地字节序
         */
        ival = ntohl(*((uint32_t *)iptr));

        /*
         * TEXT 的二进制表现形式是文本，因此libpq能够给它附加一个字节零
         * 把它看做 C 字符串
         *
         */

        printf("tuple %d: got\n", i);
        printf(" i = (%d bytes) %d\n",
               PQgetlength(res, i, i_fnum), ival);
        printf(" t = (%d bytes) '%s'\n",
               PQgetlength(res, i, t_fnum), tptr);
        printf("\n\n");
    }
}

int main(int argc, char **argv)
{
    const char *conninfo;
    PGconn *conn;
    PGresult *res;
    const char *paramValues[1];
    int paramLengths[1];
    int paramFormats[1];
    uint32_t binaryIntVal;

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

    /* 把整数值 "2" 转换成网络字节序 */
    binaryIntVal = htonl((uint32_t)25);

    /* 为 PQexecParams 设置参数数组 */
    paramValues[0] = (char *)&binaryIntVal;
    paramLengths[0] = sizeof(binaryIntVal);
    paramFormats[0] = 1; /* 二进制 */

    res = PQexecParams(conn,
                       "SELECT * FROM customer_t1 WHERE c_customer_sk = $1::int4",
                       1,    /* 一个参数 */
                       NULL, /* 让后端推导参数类型 */
                       paramValues,
                       paramLengths,
                       paramFormats,
                       1); /* 要求二进制结果 */

    if (PQresultStatus(res) != PGRES_TUPLES_OK)
    {
        fprintf(stderr, "SELECT failed: %s", PQerrorMessage(conn));
        PQclear(res);
        exit_nicely(conn);
    }
    else
        printf("SELECT command executed successfully.\n");

    show_binary_results(res);

    PQclear(res);

    /* 关闭与数据库的连接并清理 */
    PQfinish(conn);

    return 0;
}
