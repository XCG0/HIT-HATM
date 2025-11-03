/* A Bison parser, made by GNU Bison 3.8.2.  */

/* Bison interface for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2015, 2018-2021 Free Software Foundation,
   Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* DO NOT RELY ON FEATURES THAT ARE NOT DOCUMENTED in the manual,
   especially those whose name start with YY_ or yy_.  They are
   private implementation details that can be changed or removed.  */

#ifndef YY_BASE_YY_PREPROC_HPP_INCLUDED
# define YY_BASE_YY_PREPROC_HPP_INCLUDED
/* Debug traces.  */
#ifndef YYDEBUG
# define YYDEBUG 1
#endif
#if YYDEBUG
extern int base_yydebug;
#endif

/* Token kinds.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    YYEMPTY = -2,
    YYEOF = 0,                     /* "end of file"  */
    YYerror = 256,                 /* error  */
    YYUNDEF = 257,                 /* "invalid token"  */
    SQL_ALLOCATE = 258,            /* SQL_ALLOCATE  */
    SQL_AUTOCOMMIT = 259,          /* SQL_AUTOCOMMIT  */
    SQL_BOOL = 260,                /* SQL_BOOL  */
    SQL_BREAK = 261,               /* SQL_BREAK  */
    SQL_CALL = 262,                /* SQL_CALL  */
    SQL_CARDINALITY = 263,         /* SQL_CARDINALITY  */
    SQL_COUNT = 264,               /* SQL_COUNT  */
    SQL_DATETIME_INTERVAL_CODE = 265, /* SQL_DATETIME_INTERVAL_CODE  */
    SQL_DATETIME_INTERVAL_PRECISION = 266, /* SQL_DATETIME_INTERVAL_PRECISION  */
    SQL_DESCRIBE = 267,            /* SQL_DESCRIBE  */
    SQL_DESCRIPTOR = 268,          /* SQL_DESCRIPTOR  */
    SQL_FOUND = 269,               /* SQL_FOUND  */
    SQL_FREE = 270,                /* SQL_FREE  */
    SQL_GET = 271,                 /* SQL_GET  */
    SQL_GO = 272,                  /* SQL_GO  */
    SQL_GOTO = 273,                /* SQL_GOTO  */
    SQL_IDENTIFIED = 274,          /* SQL_IDENTIFIED  */
    SQL_INDICATOR = 275,           /* SQL_INDICATOR  */
    SQL_KEY_MEMBER = 276,          /* SQL_KEY_MEMBER  */
    SQL_LENGTH = 277,              /* SQL_LENGTH  */
    SQL_LONG = 278,                /* SQL_LONG  */
    SQL_NULLABLE = 279,            /* SQL_NULLABLE  */
    SQL_OCTET_LENGTH = 280,        /* SQL_OCTET_LENGTH  */
    SQL_OPEN = 281,                /* SQL_OPEN  */
    SQL_OUTPUT = 282,              /* SQL_OUTPUT  */
    SQL_REFERENCE = 283,           /* SQL_REFERENCE  */
    SQL_RETURNED_LENGTH = 284,     /* SQL_RETURNED_LENGTH  */
    SQL_RETURNED_OCTET_LENGTH = 285, /* SQL_RETURNED_OCTET_LENGTH  */
    SQL_SCALE = 286,               /* SQL_SCALE  */
    SQL_SECTION = 287,             /* SQL_SECTION  */
    SQL_SHORT = 288,               /* SQL_SHORT  */
    SQL_SIGNED = 289,              /* SQL_SIGNED  */
    SQL_SQL = 290,                 /* SQL_SQL  */
    SQL_SQLERROR = 291,            /* SQL_SQLERROR  */
    SQL_SQLPRINT = 292,            /* SQL_SQLPRINT  */
    SQL_SQLWARNING = 293,          /* SQL_SQLWARNING  */
    SQL_START = 294,               /* SQL_START  */
    SQL_STOP = 295,                /* SQL_STOP  */
    SQL_STRUCT = 296,              /* SQL_STRUCT  */
    SQL_UNSIGNED = 297,            /* SQL_UNSIGNED  */
    SQL_VAR = 298,                 /* SQL_VAR  */
    SQL_WHENEVER = 299,            /* SQL_WHENEVER  */
    S_ADD = 300,                   /* S_ADD  */
    S_AND = 301,                   /* S_AND  */
    S_ANYTHING = 302,              /* S_ANYTHING  */
    S_AUTO = 303,                  /* S_AUTO  */
    S_CONST = 304,                 /* S_CONST  */
    S_DEC = 305,                   /* S_DEC  */
    S_DIV = 306,                   /* S_DIV  */
    S_DOTPOINT = 307,              /* S_DOTPOINT  */
    S_EQUAL = 308,                 /* S_EQUAL  */
    S_EXTERN = 309,                /* S_EXTERN  */
    S_INC = 310,                   /* S_INC  */
    S_LSHIFT = 311,                /* S_LSHIFT  */
    S_MEMPOINT = 312,              /* S_MEMPOINT  */
    S_MEMBER = 313,                /* S_MEMBER  */
    S_MOD = 314,                   /* S_MOD  */
    S_MUL = 315,                   /* S_MUL  */
    S_NEQUAL = 316,                /* S_NEQUAL  */
    S_OR = 317,                    /* S_OR  */
    S_REGISTER = 318,              /* S_REGISTER  */
    S_RSHIFT = 319,                /* S_RSHIFT  */
    S_STATIC = 320,                /* S_STATIC  */
    S_SUB = 321,                   /* S_SUB  */
    S_VOLATILE = 322,              /* S_VOLATILE  */
    S_TYPEDEF = 323,               /* S_TYPEDEF  */
    CSTRING = 324,                 /* CSTRING  */
    CVARIABLE = 325,               /* CVARIABLE  */
    CPP_LINE = 326,                /* CPP_LINE  */
    SQL_IP = 327,                  /* SQL_IP  */
    DOLCONST = 328,                /* DOLCONST  */
    ECONST = 329,                  /* ECONST  */
    NCONST = 330,                  /* NCONST  */
    UCONST = 331,                  /* UCONST  */
    UIDENT = 332,                  /* UIDENT  */
    IDENT = 333,                   /* IDENT  */
    FCONST = 334,                  /* FCONST  */
    SCONST = 335,                  /* SCONST  */
    BCONST = 336,                  /* BCONST  */
    VCONST = 337,                  /* VCONST  */
    XCONST = 338,                  /* XCONST  */
    Op = 339,                      /* Op  */
    CmpOp = 340,                   /* CmpOp  */
    CmpNullOp = 341,               /* CmpNullOp  */
    COMMENTSTRING = 342,           /* COMMENTSTRING  */
    SET_USER_IDENT = 343,          /* SET_USER_IDENT  */
    SET_IDENT = 344,               /* SET_IDENT  */
    UNDERSCORE_CHARSET = 345,      /* UNDERSCORE_CHARSET  */
    ICONST = 346,                  /* ICONST  */
    PARAM = 347,                   /* PARAM  */
    TYPECAST = 348,                /* TYPECAST  */
    ORA_JOINOP = 349,              /* ORA_JOINOP  */
    DOT_DOT = 350,                 /* DOT_DOT  */
    COLON_EQUALS = 351,            /* COLON_EQUALS  */
    PARA_EQUALS = 352,             /* PARA_EQUALS  */
    SET_IDENT_SESSION = 353,       /* SET_IDENT_SESSION  */
    SET_IDENT_GLOBAL = 354,        /* SET_IDENT_GLOBAL  */
    ABORT_P = 355,                 /* ABORT_P  */
    ABSOLUTE_P = 356,              /* ABSOLUTE_P  */
    ACCESS = 357,                  /* ACCESS  */
    ACCOUNT = 358,                 /* ACCOUNT  */
    ACTION = 359,                  /* ACTION  */
    ADD_P = 360,                   /* ADD_P  */
    ADMIN = 361,                   /* ADMIN  */
    AFTER = 362,                   /* AFTER  */
    AGGREGATE = 363,               /* AGGREGATE  */
    ALGORITHM = 364,               /* ALGORITHM  */
    ALL = 365,                     /* ALL  */
    ALSO = 366,                    /* ALSO  */
    ALTER = 367,                   /* ALTER  */
    ALWAYS = 368,                  /* ALWAYS  */
    ANALYSE = 369,                 /* ANALYSE  */
    ANALYZE = 370,                 /* ANALYZE  */
    AND = 371,                     /* AND  */
    ANY = 372,                     /* ANY  */
    APP = 373,                     /* APP  */
    APPEND = 374,                  /* APPEND  */
    ARCHIVE = 375,                 /* ARCHIVE  */
    ARRAY = 376,                   /* ARRAY  */
    AS = 377,                      /* AS  */
    ASC = 378,                     /* ASC  */
    ASSERTION = 379,               /* ASSERTION  */
    ASSIGNMENT = 380,              /* ASSIGNMENT  */
    ASYMMETRIC = 381,              /* ASYMMETRIC  */
    AT = 382,                      /* AT  */
    ATTRIBUTE = 383,               /* ATTRIBUTE  */
    AUDIT = 384,                   /* AUDIT  */
    AUTHID = 385,                  /* AUTHID  */
    AUTHORIZATION = 386,           /* AUTHORIZATION  */
    AUTOEXTEND = 387,              /* AUTOEXTEND  */
    AUTOMAPPED = 388,              /* AUTOMAPPED  */
    AUTO_INCREMENT = 389,          /* AUTO_INCREMENT  */
    BACKWARD = 390,                /* BACKWARD  */
    BARRIER = 391,                 /* BARRIER  */
    BEFORE = 392,                  /* BEFORE  */
    BEGIN_NON_ANOYBLOCK = 393,     /* BEGIN_NON_ANOYBLOCK  */
    BEGIN_P = 394,                 /* BEGIN_P  */
    BETWEEN = 395,                 /* BETWEEN  */
    BIGINT = 396,                  /* BIGINT  */
    BINARY = 397,                  /* BINARY  */
    BINARY_DOUBLE = 398,           /* BINARY_DOUBLE  */
    BINARY_INTEGER = 399,          /* BINARY_INTEGER  */
    BIT = 400,                     /* BIT  */
    BLANKS = 401,                  /* BLANKS  */
    BLOB_P = 402,                  /* BLOB_P  */
    BLOCKCHAIN = 403,              /* BLOCKCHAIN  */
    BODY_P = 404,                  /* BODY_P  */
    BOGUS = 405,                   /* BOGUS  */
    BOOLEAN_P = 406,               /* BOOLEAN_P  */
    BOTH = 407,                    /* BOTH  */
    BUCKETCNT = 408,               /* BUCKETCNT  */
    BUCKETS = 409,                 /* BUCKETS  */
    BY = 410,                      /* BY  */
    BYTEAWITHOUTORDER = 411,       /* BYTEAWITHOUTORDER  */
    BYTEAWITHOUTORDERWITHEQUAL = 412, /* BYTEAWITHOUTORDERWITHEQUAL  */
    CACHE = 413,                   /* CACHE  */
    CALL = 414,                    /* CALL  */
    CALLED = 415,                  /* CALLED  */
    CANCELABLE = 416,              /* CANCELABLE  */
    CASCADE = 417,                 /* CASCADE  */
    CASCADED = 418,                /* CASCADED  */
    CASE = 419,                    /* CASE  */
    CAST = 420,                    /* CAST  */
    CATALOG_P = 421,               /* CATALOG_P  */
    CHAIN = 422,                   /* CHAIN  */
    CHANGE = 423,                  /* CHANGE  */
    CHAR_P = 424,                  /* CHAR_P  */
    CHARACTER = 425,               /* CHARACTER  */
    CHARACTERISTICS = 426,         /* CHARACTERISTICS  */
    CHARACTERSET = 427,            /* CHARACTERSET  */
    CHARSET = 428,                 /* CHARSET  */
    CHECK = 429,                   /* CHECK  */
    CHECKPOINT = 430,              /* CHECKPOINT  */
    CLASS = 431,                   /* CLASS  */
    CLEAN = 432,                   /* CLEAN  */
    CLIENT = 433,                  /* CLIENT  */
    CLIENT_MASTER_KEY = 434,       /* CLIENT_MASTER_KEY  */
    CLIENT_MASTER_KEYS = 435,      /* CLIENT_MASTER_KEYS  */
    CLOB = 436,                    /* CLOB  */
    CLOSE = 437,                   /* CLOSE  */
    CLUSTER = 438,                 /* CLUSTER  */
    COALESCE = 439,                /* COALESCE  */
    COLLATE = 440,                 /* COLLATE  */
    COLLATION = 441,               /* COLLATION  */
    COLUMN = 442,                  /* COLUMN  */
    COLUMN_ENCRYPTION_KEY = 443,   /* COLUMN_ENCRYPTION_KEY  */
    COLUMN_ENCRYPTION_KEYS = 444,  /* COLUMN_ENCRYPTION_KEYS  */
    COLUMNS = 445,                 /* COLUMNS  */
    COMMENT = 446,                 /* COMMENT  */
    COMMENTS = 447,                /* COMMENTS  */
    COMMIT = 448,                  /* COMMIT  */
    COMMITTED = 449,               /* COMMITTED  */
    COMPACT = 450,                 /* COMPACT  */
    COMPATIBLE_ILLEGAL_CHARS = 451, /* COMPATIBLE_ILLEGAL_CHARS  */
    COMPLETE = 452,                /* COMPLETE  */
    COMPLETION = 453,              /* COMPLETION  */
    COMPRESS = 454,                /* COMPRESS  */
    CONCURRENTLY = 455,            /* CONCURRENTLY  */
    CONDITION = 456,               /* CONDITION  */
    CONFIGURATION = 457,           /* CONFIGURATION  */
    CONNECTION = 458,              /* CONNECTION  */
    CONSTANT = 459,                /* CONSTANT  */
    CONSTRAINT = 460,              /* CONSTRAINT  */
    CONSTRAINTS = 461,             /* CONSTRAINTS  */
    CONTENT_P = 462,               /* CONTENT_P  */
    CONTINUE_P = 463,              /* CONTINUE_P  */
    CONTVIEW = 464,                /* CONTVIEW  */
    CONVERSION_P = 465,            /* CONVERSION_P  */
    CONVERT_P = 466,               /* CONVERT_P  */
    CONNECT = 467,                 /* CONNECT  */
    COORDINATOR = 468,             /* COORDINATOR  */
    COORDINATORS = 469,            /* COORDINATORS  */
    COPY = 470,                    /* COPY  */
    COST = 471,                    /* COST  */
    CREATE = 472,                  /* CREATE  */
    CROSS = 473,                   /* CROSS  */
    CSN = 474,                     /* CSN  */
    CSV = 475,                     /* CSV  */
    CUBE = 476,                    /* CUBE  */
    CURRENT_P = 477,               /* CURRENT_P  */
    CURRENT_CATALOG = 478,         /* CURRENT_CATALOG  */
    CURRENT_DATE = 479,            /* CURRENT_DATE  */
    CURRENT_ROLE = 480,            /* CURRENT_ROLE  */
    CURRENT_SCHEMA = 481,          /* CURRENT_SCHEMA  */
    CURRENT_TIME = 482,            /* CURRENT_TIME  */
    CURRENT_TIMESTAMP = 483,       /* CURRENT_TIMESTAMP  */
    CURRENT_USER = 484,            /* CURRENT_USER  */
    CURSOR = 485,                  /* CURSOR  */
    CYCLE = 486,                   /* CYCLE  */
    SHRINK = 487,                  /* SHRINK  */
    USE_P = 488,                   /* USE_P  */
    DATA_P = 489,                  /* DATA_P  */
    DATABASE = 490,                /* DATABASE  */
    DATAFILE = 491,                /* DATAFILE  */
    DATANODE = 492,                /* DATANODE  */
    DATANODES = 493,               /* DATANODES  */
    DATATYPE_CL = 494,             /* DATATYPE_CL  */
    DATE_P = 495,                  /* DATE_P  */
    DATE_FORMAT_P = 496,           /* DATE_FORMAT_P  */
    DAY_P = 497,                   /* DAY_P  */
    DAY_HOUR_P = 498,              /* DAY_HOUR_P  */
    DAY_MINUTE_P = 499,            /* DAY_MINUTE_P  */
    DAY_SECOND_P = 500,            /* DAY_SECOND_P  */
    DBCOMPATIBILITY_P = 501,       /* DBCOMPATIBILITY_P  */
    DEALLOCATE = 502,              /* DEALLOCATE  */
    DEC = 503,                     /* DEC  */
    DECIMAL_P = 504,               /* DECIMAL_P  */
    DECLARE = 505,                 /* DECLARE  */
    DECODE = 506,                  /* DECODE  */
    DEFAULT = 507,                 /* DEFAULT  */
    DEFAULTS = 508,                /* DEFAULTS  */
    DEFERRABLE = 509,              /* DEFERRABLE  */
    DEFERRED = 510,                /* DEFERRED  */
    DEFINER = 511,                 /* DEFINER  */
    DELETE_P = 512,                /* DELETE_P  */
    DELIMITER = 513,               /* DELIMITER  */
    DELIMITERS = 514,              /* DELIMITERS  */
    DELTA = 515,                   /* DELTA  */
    DELTAMERGE = 516,              /* DELTAMERGE  */
    DESC = 517,                    /* DESC  */
    DETERMINISTIC = 518,           /* DETERMINISTIC  */
    DICTIONARY = 519,              /* DICTIONARY  */
    DIRECT = 520,                  /* DIRECT  */
    DIRECTORY = 521,               /* DIRECTORY  */
    DISABLE_P = 522,               /* DISABLE_P  */
    DISCARD = 523,                 /* DISCARD  */
    DISTINCT = 524,                /* DISTINCT  */
    DISTRIBUTE = 525,              /* DISTRIBUTE  */
    DISTRIBUTION = 526,            /* DISTRIBUTION  */
    DO = 527,                      /* DO  */
    DOCUMENT_P = 528,              /* DOCUMENT_P  */
    DOMAIN_P = 529,                /* DOMAIN_P  */
    DOUBLE_P = 530,                /* DOUBLE_P  */
    DROP = 531,                    /* DROP  */
    DUPLICATE = 532,               /* DUPLICATE  */
    DISCONNECT = 533,              /* DISCONNECT  */
    DUMPFILE = 534,                /* DUMPFILE  */
    EACH = 535,                    /* EACH  */
    ELASTIC = 536,                 /* ELASTIC  */
    ELSE = 537,                    /* ELSE  */
    ENABLE_P = 538,                /* ENABLE_P  */
    ENCLOSED = 539,                /* ENCLOSED  */
    ENCODING = 540,                /* ENCODING  */
    ENCRYPTED = 541,               /* ENCRYPTED  */
    ENCRYPTED_VALUE = 542,         /* ENCRYPTED_VALUE  */
    ENCRYPTION = 543,              /* ENCRYPTION  */
    ENCRYPTION_TYPE = 544,         /* ENCRYPTION_TYPE  */
    END_P = 545,                   /* END_P  */
    ENDS = 546,                    /* ENDS  */
    ENFORCED = 547,                /* ENFORCED  */
    ENUM_P = 548,                  /* ENUM_P  */
    ERRORS = 549,                  /* ERRORS  */
    ESCAPE = 550,                  /* ESCAPE  */
    EOL = 551,                     /* EOL  */
    ESCAPING = 552,                /* ESCAPING  */
    EVENT = 553,                   /* EVENT  */
    EVENTS = 554,                  /* EVENTS  */
    EVERY = 555,                   /* EVERY  */
    EXCEPT = 556,                  /* EXCEPT  */
    EXCHANGE = 557,                /* EXCHANGE  */
    EXCLUDE = 558,                 /* EXCLUDE  */
    EXCLUDED = 559,                /* EXCLUDED  */
    EXCLUDING = 560,               /* EXCLUDING  */
    EXCLUSIVE = 561,               /* EXCLUSIVE  */
    EXECUTE = 562,                 /* EXECUTE  */
    EXISTS = 563,                  /* EXISTS  */
    EXPIRED_P = 564,               /* EXPIRED_P  */
    EXPLAIN = 565,                 /* EXPLAIN  */
    EXTENSION = 566,               /* EXTENSION  */
    EXTERNAL = 567,                /* EXTERNAL  */
    EXTRACT = 568,                 /* EXTRACT  */
    ESCAPED = 569,                 /* ESCAPED  */
    FALSE_P = 570,                 /* FALSE_P  */
    FAMILY = 571,                  /* FAMILY  */
    FAST = 572,                    /* FAST  */
    FENCED = 573,                  /* FENCED  */
    FETCH = 574,                   /* FETCH  */
    FIELDS = 575,                  /* FIELDS  */
    FILEHEADER_P = 576,            /* FILEHEADER_P  */
    FILL_MISSING_FIELDS = 577,     /* FILL_MISSING_FIELDS  */
    FILLER = 578,                  /* FILLER  */
    FILTER = 579,                  /* FILTER  */
    FIRST_P = 580,                 /* FIRST_P  */
    FIXED_P = 581,                 /* FIXED_P  */
    FLOAT_P = 582,                 /* FLOAT_P  */
    FOLLOWING = 583,               /* FOLLOWING  */
    FOLLOWS_P = 584,               /* FOLLOWS_P  */
    FOR = 585,                     /* FOR  */
    FORCE = 586,                   /* FORCE  */
    FOREIGN = 587,                 /* FOREIGN  */
    FORMATTER = 588,               /* FORMATTER  */
    FORWARD = 589,                 /* FORWARD  */
    FEATURES = 590,                /* FEATURES  */
    FREEZE = 591,                  /* FREEZE  */
    FROM = 592,                    /* FROM  */
    FULL = 593,                    /* FULL  */
    FUNCTION = 594,                /* FUNCTION  */
    FUNCTIONS = 595,               /* FUNCTIONS  */
    GENERATED = 596,               /* GENERATED  */
    GLOBAL = 597,                  /* GLOBAL  */
    GRANT = 598,                   /* GRANT  */
    GRANTED = 599,                 /* GRANTED  */
    GREATEST = 600,                /* GREATEST  */
    GROUP_P = 601,                 /* GROUP_P  */
    GROUPING_P = 602,              /* GROUPING_P  */
    GROUPPARENT = 603,             /* GROUPPARENT  */
    HANDLER = 604,                 /* HANDLER  */
    HAVING = 605,                  /* HAVING  */
    HDFSDIRECTORY = 606,           /* HDFSDIRECTORY  */
    HEADER_P = 607,                /* HEADER_P  */
    HOLD = 608,                    /* HOLD  */
    HOUR_P = 609,                  /* HOUR_P  */
    HOUR_MINUTE_P = 610,           /* HOUR_MINUTE_P  */
    HOUR_SECOND_P = 611,           /* HOUR_SECOND_P  */
    IDENTIFIED = 612,              /* IDENTIFIED  */
    IDENTITY_P = 613,              /* IDENTITY_P  */
    IF_P = 614,                    /* IF_P  */
    IGNORE = 615,                  /* IGNORE  */
    IGNORE_EXTRA_DATA = 616,       /* IGNORE_EXTRA_DATA  */
    ILIKE = 617,                   /* ILIKE  */
    IMMEDIATE = 618,               /* IMMEDIATE  */
    IMMUTABLE = 619,               /* IMMUTABLE  */
    IMPLICIT_P = 620,              /* IMPLICIT_P  */
    IN_P = 621,                    /* IN_P  */
    INCLUDE = 622,                 /* INCLUDE  */
    INCLUDING = 623,               /* INCLUDING  */
    INCREMENT = 624,               /* INCREMENT  */
    INCREMENTAL = 625,             /* INCREMENTAL  */
    INDEX = 626,                   /* INDEX  */
    INDEXES = 627,                 /* INDEXES  */
    INFILE = 628,                  /* INFILE  */
    INHERIT = 629,                 /* INHERIT  */
    INHERITS = 630,                /* INHERITS  */
    INITIAL_P = 631,               /* INITIAL_P  */
    INITIALLY = 632,               /* INITIALLY  */
    INITRANS = 633,                /* INITRANS  */
    INLINE_P = 634,                /* INLINE_P  */
    INNER_P = 635,                 /* INNER_P  */
    INOUT = 636,                   /* INOUT  */
    INPUT_P = 637,                 /* INPUT_P  */
    INSENSITIVE = 638,             /* INSENSITIVE  */
    INSERT = 639,                  /* INSERT  */
    INSTEAD = 640,                 /* INSTEAD  */
    INT_P = 641,                   /* INT_P  */
    INTEGER = 642,                 /* INTEGER  */
    INTERNAL = 643,                /* INTERNAL  */
    INTERSECT = 644,               /* INTERSECT  */
    INTERVAL = 645,                /* INTERVAL  */
    INTO = 646,                    /* INTO  */
    INVISIBLE = 647,               /* INVISIBLE  */
    INVOKER = 648,                 /* INVOKER  */
    IP = 649,                      /* IP  */
    IS = 650,                      /* IS  */
    ISNULL = 651,                  /* ISNULL  */
    ISOLATION = 652,               /* ISOLATION  */
    JOIN = 653,                    /* JOIN  */
    KEY = 654,                     /* KEY  */
    KILL = 655,                    /* KILL  */
    KEY_PATH = 656,                /* KEY_PATH  */
    KEY_STORE = 657,               /* KEY_STORE  */
    LABEL = 658,                   /* LABEL  */
    LANGUAGE = 659,                /* LANGUAGE  */
    LARGE_P = 660,                 /* LARGE_P  */
    LAST_P = 661,                  /* LAST_P  */
    LC_COLLATE_P = 662,            /* LC_COLLATE_P  */
    LC_CTYPE_P = 663,              /* LC_CTYPE_P  */
    LEADING = 664,                 /* LEADING  */
    LEAKPROOF = 665,               /* LEAKPROOF  */
    LINES = 666,                   /* LINES  */
    LEAST = 667,                   /* LEAST  */
    LESS = 668,                    /* LESS  */
    LEFT = 669,                    /* LEFT  */
    LEVEL = 670,                   /* LEVEL  */
    LIKE = 671,                    /* LIKE  */
    LIMIT = 672,                   /* LIMIT  */
    LIST = 673,                    /* LIST  */
    LISTEN = 674,                  /* LISTEN  */
    LOAD = 675,                    /* LOAD  */
    LOCAL = 676,                   /* LOCAL  */
    LOCALTIME = 677,               /* LOCALTIME  */
    LOCALTIMESTAMP = 678,          /* LOCALTIMESTAMP  */
    LOCATION = 679,                /* LOCATION  */
    LOCK_P = 680,                  /* LOCK_P  */
    LOCKED = 681,                  /* LOCKED  */
    LOG_P = 682,                   /* LOG_P  */
    LOGGING = 683,                 /* LOGGING  */
    LOGIN_ANY = 684,               /* LOGIN_ANY  */
    LOGIN_FAILURE = 685,           /* LOGIN_FAILURE  */
    LOGIN_SUCCESS = 686,           /* LOGIN_SUCCESS  */
    LOGOUT = 687,                  /* LOGOUT  */
    LOOP = 688,                    /* LOOP  */
    MAPPING = 689,                 /* MAPPING  */
    MASKING = 690,                 /* MASKING  */
    MASTER = 691,                  /* MASTER  */
    MATCH = 692,                   /* MATCH  */
    MATERIALIZED = 693,            /* MATERIALIZED  */
    MATCHED = 694,                 /* MATCHED  */
    MAXEXTENTS = 695,              /* MAXEXTENTS  */
    MAXSIZE = 696,                 /* MAXSIZE  */
    MAXTRANS = 697,                /* MAXTRANS  */
    MAXVALUE = 698,                /* MAXVALUE  */
    MERGE = 699,                   /* MERGE  */
    MINUS_P = 700,                 /* MINUS_P  */
    MINUTE_P = 701,                /* MINUTE_P  */
    MINUTE_SECOND_P = 702,         /* MINUTE_SECOND_P  */
    MINVALUE = 703,                /* MINVALUE  */
    MINEXTENTS = 704,              /* MINEXTENTS  */
    MODE = 705,                    /* MODE  */
    MODIFY_P = 706,                /* MODIFY_P  */
    MONTH_P = 707,                 /* MONTH_P  */
    MOVE = 708,                    /* MOVE  */
    MOVEMENT = 709,                /* MOVEMENT  */
    MODEL = 710,                   /* MODEL  */
    NAME_P = 711,                  /* NAME_P  */
    NAMES = 712,                   /* NAMES  */
    NATIONAL = 713,                /* NATIONAL  */
    NATURAL = 714,                 /* NATURAL  */
    NCHAR = 715,                   /* NCHAR  */
    NEXT = 716,                    /* NEXT  */
    NO = 717,                      /* NO  */
    NOCOMPRESS = 718,              /* NOCOMPRESS  */
    NOCYCLE = 719,                 /* NOCYCLE  */
    NODE = 720,                    /* NODE  */
    NOLOGGING = 721,               /* NOLOGGING  */
    NOMAXVALUE = 722,              /* NOMAXVALUE  */
    NOMINVALUE = 723,              /* NOMINVALUE  */
    NONE = 724,                    /* NONE  */
    NOT = 725,                     /* NOT  */
    NOTHING = 726,                 /* NOTHING  */
    NOTIFY = 727,                  /* NOTIFY  */
    NOTNULL = 728,                 /* NOTNULL  */
    NOWAIT = 729,                  /* NOWAIT  */
    NULL_P = 730,                  /* NULL_P  */
    NULLCOLS = 731,                /* NULLCOLS  */
    NULLIF = 732,                  /* NULLIF  */
    NULLS_P = 733,                 /* NULLS_P  */
    NUMBER_P = 734,                /* NUMBER_P  */
    NUMERIC = 735,                 /* NUMERIC  */
    NUMSTR = 736,                  /* NUMSTR  */
    NVARCHAR = 737,                /* NVARCHAR  */
    NVARCHAR2 = 738,               /* NVARCHAR2  */
    NVL = 739,                     /* NVL  */
    OBJECT_P = 740,                /* OBJECT_P  */
    OF = 741,                      /* OF  */
    OFF = 742,                     /* OFF  */
    OFFSET = 743,                  /* OFFSET  */
    OIDS = 744,                    /* OIDS  */
    ON = 745,                      /* ON  */
    ONLY = 746,                    /* ONLY  */
    OPERATOR = 747,                /* OPERATOR  */
    OPTIMIZATION = 748,            /* OPTIMIZATION  */
    OPTION = 749,                  /* OPTION  */
    OPTIONALLY = 750,              /* OPTIONALLY  */
    OPTIONS = 751,                 /* OPTIONS  */
    OR = 752,                      /* OR  */
    ORDER = 753,                   /* ORDER  */
    OUT_P = 754,                   /* OUT_P  */
    OUTER_P = 755,                 /* OUTER_P  */
    OVER = 756,                    /* OVER  */
    OVERLAPS = 757,                /* OVERLAPS  */
    OVERLAY = 758,                 /* OVERLAY  */
    OWNED = 759,                   /* OWNED  */
    OWNER = 760,                   /* OWNER  */
    OUTFILE = 761,                 /* OUTFILE  */
    PACKAGE = 762,                 /* PACKAGE  */
    PACKAGES = 763,                /* PACKAGES  */
    PARSER = 764,                  /* PARSER  */
    PARTIAL = 765,                 /* PARTIAL  */
    PARTITION = 766,               /* PARTITION  */
    PARTITIONS = 767,              /* PARTITIONS  */
    PASSING = 768,                 /* PASSING  */
    PASSWORD = 769,                /* PASSWORD  */
    PCTFREE = 770,                 /* PCTFREE  */
    PER_P = 771,                   /* PER_P  */
    PERCENT = 772,                 /* PERCENT  */
    PERFORMANCE = 773,             /* PERFORMANCE  */
    PERM = 774,                    /* PERM  */
    PLACING = 775,                 /* PLACING  */
    PLAN = 776,                    /* PLAN  */
    PLANS = 777,                   /* PLANS  */
    POLICY = 778,                  /* POLICY  */
    POSITION = 779,                /* POSITION  */
    POOL = 780,                    /* POOL  */
    PRECEDING = 781,               /* PRECEDING  */
    PRECISION = 782,               /* PRECISION  */
    PREDICT = 783,                 /* PREDICT  */
    PREFERRED = 784,               /* PREFERRED  */
    PREFIX = 785,                  /* PREFIX  */
    PRESERVE = 786,                /* PRESERVE  */
    PREPARE = 787,                 /* PREPARE  */
    PREPARED = 788,                /* PREPARED  */
    PRIMARY = 789,                 /* PRIMARY  */
    PRECEDES_P = 790,              /* PRECEDES_P  */
    PRIVATE = 791,                 /* PRIVATE  */
    PRIOR = 792,                   /* PRIOR  */
    PRIORER = 793,                 /* PRIORER  */
    PRIVILEGES = 794,              /* PRIVILEGES  */
    PRIVILEGE = 795,               /* PRIVILEGE  */
    PROCEDURAL = 796,              /* PROCEDURAL  */
    PROCEDURE = 797,               /* PROCEDURE  */
    PROFILE = 798,                 /* PROFILE  */
    PUBLICATION = 799,             /* PUBLICATION  */
    PUBLISH = 800,                 /* PUBLISH  */
    PURGE = 801,                   /* PURGE  */
    QUERY = 802,                   /* QUERY  */
    QUOTE = 803,                   /* QUOTE  */
    RANDOMIZED = 804,              /* RANDOMIZED  */
    RANGE = 805,                   /* RANGE  */
    RATIO = 806,                   /* RATIO  */
    RAW = 807,                     /* RAW  */
    READ = 808,                    /* READ  */
    REAL = 809,                    /* REAL  */
    REASSIGN = 810,                /* REASSIGN  */
    REBUILD = 811,                 /* REBUILD  */
    RECHECK = 812,                 /* RECHECK  */
    RECURSIVE = 813,               /* RECURSIVE  */
    RECYCLEBIN = 814,              /* RECYCLEBIN  */
    REDISANYVALUE = 815,           /* REDISANYVALUE  */
    REF = 816,                     /* REF  */
    REFERENCES = 817,              /* REFERENCES  */
    REFRESH = 818,                 /* REFRESH  */
    REINDEX = 819,                 /* REINDEX  */
    REJECT_P = 820,                /* REJECT_P  */
    RELATIVE_P = 821,              /* RELATIVE_P  */
    RELEASE = 822,                 /* RELEASE  */
    RELOPTIONS = 823,              /* RELOPTIONS  */
    REMOTE_P = 824,                /* REMOTE_P  */
    REMOVE = 825,                  /* REMOVE  */
    RENAME = 826,                  /* RENAME  */
    REPEAT = 827,                  /* REPEAT  */
    REPEATABLE = 828,              /* REPEATABLE  */
    REPLACE = 829,                 /* REPLACE  */
    REPLICA = 830,                 /* REPLICA  */
    RESET = 831,                   /* RESET  */
    RESIZE = 832,                  /* RESIZE  */
    RESOURCE = 833,                /* RESOURCE  */
    RESTART = 834,                 /* RESTART  */
    RESTRICT = 835,                /* RESTRICT  */
    RETURN = 836,                  /* RETURN  */
    RETURNING = 837,               /* RETURNING  */
    RETURNS = 838,                 /* RETURNS  */
    REUSE = 839,                   /* REUSE  */
    REVOKE = 840,                  /* REVOKE  */
    RIGHT = 841,                   /* RIGHT  */
    ROLE = 842,                    /* ROLE  */
    ROLES = 843,                   /* ROLES  */
    ROLLBACK = 844,                /* ROLLBACK  */
    ROLLUP = 845,                  /* ROLLUP  */
    ROTATION = 846,                /* ROTATION  */
    ROW = 847,                     /* ROW  */
    ROWNUM = 848,                  /* ROWNUM  */
    ROWS = 849,                    /* ROWS  */
    ROWTYPE_P = 850,               /* ROWTYPE_P  */
    RULE = 851,                    /* RULE  */
    SAMPLE = 852,                  /* SAMPLE  */
    SAVEPOINT = 853,               /* SAVEPOINT  */
    SCHEDULE = 854,                /* SCHEDULE  */
    SCHEMA = 855,                  /* SCHEMA  */
    SCROLL = 856,                  /* SCROLL  */
    SEARCH = 857,                  /* SEARCH  */
    SECOND_P = 858,                /* SECOND_P  */
    SECURITY = 859,                /* SECURITY  */
    SELECT = 860,                  /* SELECT  */
    SEPARATOR_P = 861,             /* SEPARATOR_P  */
    SEQUENCE = 862,                /* SEQUENCE  */
    SEQUENCES = 863,               /* SEQUENCES  */
    SERIALIZABLE = 864,            /* SERIALIZABLE  */
    SERVER = 865,                  /* SERVER  */
    SESSION = 866,                 /* SESSION  */
    SESSION_USER = 867,            /* SESSION_USER  */
    SET = 868,                     /* SET  */
    SETS = 869,                    /* SETS  */
    SETOF = 870,                   /* SETOF  */
    SHARE = 871,                   /* SHARE  */
    SHIPPABLE = 872,               /* SHIPPABLE  */
    SHOW = 873,                    /* SHOW  */
    SHUTDOWN = 874,                /* SHUTDOWN  */
    SIBLINGS = 875,                /* SIBLINGS  */
    SIMILAR = 876,                 /* SIMILAR  */
    SIMPLE = 877,                  /* SIMPLE  */
    SIZE = 878,                    /* SIZE  */
    SKIP = 879,                    /* SKIP  */
    SLAVE = 880,                   /* SLAVE  */
    SLICE = 881,                   /* SLICE  */
    SMALLDATETIME = 882,           /* SMALLDATETIME  */
    SMALLDATETIME_FORMAT_P = 883,  /* SMALLDATETIME_FORMAT_P  */
    SMALLINT = 884,                /* SMALLINT  */
    SNAPSHOT = 885,                /* SNAPSHOT  */
    SOME = 886,                    /* SOME  */
    SOURCE_P = 887,                /* SOURCE_P  */
    SPACE = 888,                   /* SPACE  */
    SPILL = 889,                   /* SPILL  */
    SPLIT = 890,                   /* SPLIT  */
    STABLE = 891,                  /* STABLE  */
    STANDALONE_P = 892,            /* STANDALONE_P  */
    START = 893,                   /* START  */
    STARTS = 894,                  /* STARTS  */
    STARTWITH = 895,               /* STARTWITH  */
    STATEMENT = 896,               /* STATEMENT  */
    STATEMENT_ID = 897,            /* STATEMENT_ID  */
    STATISTICS = 898,              /* STATISTICS  */
    STDIN = 899,                   /* STDIN  */
    STDOUT = 900,                  /* STDOUT  */
    STORAGE = 901,                 /* STORAGE  */
    STORE_P = 902,                 /* STORE_P  */
    STORED = 903,                  /* STORED  */
    STRATIFY = 904,                /* STRATIFY  */
    STREAM = 905,                  /* STREAM  */
    STRICT_P = 906,                /* STRICT_P  */
    STRIP_P = 907,                 /* STRIP_P  */
    SUBPARTITION = 908,            /* SUBPARTITION  */
    SUBPARTITIONS = 909,           /* SUBPARTITIONS  */
    SUBSCRIPTION = 910,            /* SUBSCRIPTION  */
    SUBSTRING = 911,               /* SUBSTRING  */
    SYMMETRIC = 912,               /* SYMMETRIC  */
    SYNONYM = 913,                 /* SYNONYM  */
    SYSDATE = 914,                 /* SYSDATE  */
    SYSID = 915,                   /* SYSID  */
    SYSTEM_P = 916,                /* SYSTEM_P  */
    SYS_REFCURSOR = 917,           /* SYS_REFCURSOR  */
    STARTING = 918,                /* STARTING  */
    SHOW_ERRORS = 919,             /* SHOW_ERRORS  */
    SQL_P = 920,                   /* SQL_P  */
    TABLE = 921,                   /* TABLE  */
    TABLES = 922,                  /* TABLES  */
    TABLESAMPLE = 923,             /* TABLESAMPLE  */
    TABLESPACE = 924,              /* TABLESPACE  */
    TARGET = 925,                  /* TARGET  */
    TEMP = 926,                    /* TEMP  */
    TEMPLATE = 927,                /* TEMPLATE  */
    TEMPORARY = 928,               /* TEMPORARY  */
    TERMINATED = 929,              /* TERMINATED  */
    TEXT_P = 930,                  /* TEXT_P  */
    THAN = 931,                    /* THAN  */
    THEN = 932,                    /* THEN  */
    TIME = 933,                    /* TIME  */
    TIME_FORMAT_P = 934,           /* TIME_FORMAT_P  */
    TIMECAPSULE = 935,             /* TIMECAPSULE  */
    TIMESTAMP = 936,               /* TIMESTAMP  */
    TIMESTAMP_FORMAT_P = 937,      /* TIMESTAMP_FORMAT_P  */
    TIMESTAMPDIFF = 938,           /* TIMESTAMPDIFF  */
    TINYINT = 939,                 /* TINYINT  */
    TO = 940,                      /* TO  */
    TRAILING = 941,                /* TRAILING  */
    TRANSACTION = 942,             /* TRANSACTION  */
    TRANSFORM = 943,               /* TRANSFORM  */
    TREAT = 944,                   /* TREAT  */
    TRIGGER = 945,                 /* TRIGGER  */
    TRIM = 946,                    /* TRIM  */
    TRUE_P = 947,                  /* TRUE_P  */
    TRUNCATE = 948,                /* TRUNCATE  */
    TRUSTED = 949,                 /* TRUSTED  */
    TSFIELD = 950,                 /* TSFIELD  */
    TSTAG = 951,                   /* TSTAG  */
    TSTIME = 952,                  /* TSTIME  */
    TYPE_P = 953,                  /* TYPE_P  */
    TYPES_P = 954,                 /* TYPES_P  */
    UNBOUNDED = 955,               /* UNBOUNDED  */
    UNCOMMITTED = 956,             /* UNCOMMITTED  */
    UNENCRYPTED = 957,             /* UNENCRYPTED  */
    UNION = 958,                   /* UNION  */
    UNIQUE = 959,                  /* UNIQUE  */
    UNKNOWN = 960,                 /* UNKNOWN  */
    UNLIMITED = 961,               /* UNLIMITED  */
    UNLISTEN = 962,                /* UNLISTEN  */
    UNLOCK = 963,                  /* UNLOCK  */
    UNLOGGED = 964,                /* UNLOGGED  */
    UNTIL = 965,                   /* UNTIL  */
    UNUSABLE = 966,                /* UNUSABLE  */
    UPDATE = 967,                  /* UPDATE  */
    USEEOF = 968,                  /* USEEOF  */
    USER = 969,                    /* USER  */
    USING = 970,                   /* USING  */
    VACUUM = 971,                  /* VACUUM  */
    VALID = 972,                   /* VALID  */
    VALIDATE = 973,                /* VALIDATE  */
    VALIDATION = 974,              /* VALIDATION  */
    VALIDATOR = 975,               /* VALIDATOR  */
    VALUE_P = 976,                 /* VALUE_P  */
    VALUES = 977,                  /* VALUES  */
    VARCHAR = 978,                 /* VARCHAR  */
    VARCHAR2 = 979,                /* VARCHAR2  */
    VARIABLES = 980,               /* VARIABLES  */
    VARIADIC = 981,                /* VARIADIC  */
    VARRAY = 982,                  /* VARRAY  */
    VARYING = 983,                 /* VARYING  */
    VCGROUP = 984,                 /* VCGROUP  */
    VERBOSE = 985,                 /* VERBOSE  */
    VERIFY = 986,                  /* VERIFY  */
    VERSION_P = 987,               /* VERSION_P  */
    VIEW = 988,                    /* VIEW  */
    VISIBLE = 989,                 /* VISIBLE  */
    VOLATILE = 990,                /* VOLATILE  */
    WAIT = 991,                    /* WAIT  */
    WARNINGS = 992,                /* WARNINGS  */
    WEAK = 993,                    /* WEAK  */
    WHEN = 994,                    /* WHEN  */
    WHERE = 995,                   /* WHERE  */
    WHILE_P = 996,                 /* WHILE_P  */
    WHITESPACE_P = 997,            /* WHITESPACE_P  */
    WINDOW = 998,                  /* WINDOW  */
    WITH = 999,                    /* WITH  */
    WITHIN = 1000,                 /* WITHIN  */
    WITHOUT = 1001,                /* WITHOUT  */
    WORK = 1002,                   /* WORK  */
    WORKLOAD = 1003,               /* WORKLOAD  */
    WRAPPER = 1004,                /* WRAPPER  */
    WRITE = 1005,                  /* WRITE  */
    XML_P = 1006,                  /* XML_P  */
    XMLATTRIBUTES = 1007,          /* XMLATTRIBUTES  */
    XMLCONCAT = 1008,              /* XMLCONCAT  */
    XMLELEMENT = 1009,             /* XMLELEMENT  */
    XMLEXISTS = 1010,              /* XMLEXISTS  */
    XMLFOREST = 1011,              /* XMLFOREST  */
    XMLPARSE = 1012,               /* XMLPARSE  */
    XMLPI = 1013,                  /* XMLPI  */
    XMLROOT = 1014,                /* XMLROOT  */
    XMLSERIALIZE = 1015,           /* XMLSERIALIZE  */
    YEAR_P = 1016,                 /* YEAR_P  */
    YEAR_MONTH_P = 1017,           /* YEAR_MONTH_P  */
    YES_P = 1018,                  /* YES_P  */
    ZONE = 1019,                   /* ZONE  */
    NULLS_FIRST = 1020,            /* NULLS_FIRST  */
    NULLS_LAST = 1021,             /* NULLS_LAST  */
    WITH_TIME = 1022,              /* WITH_TIME  */
    INCLUDING_ALL = 1023,          /* INCLUDING_ALL  */
    RENAME_PARTITION = 1024,       /* RENAME_PARTITION  */
    PARTITION_FOR = 1025,          /* PARTITION_FOR  */
    SUBPARTITION_FOR = 1026,       /* SUBPARTITION_FOR  */
    ADD_PARTITION = 1027,          /* ADD_PARTITION  */
    DROP_PARTITION = 1028,         /* DROP_PARTITION  */
    REBUILD_PARTITION = 1029,      /* REBUILD_PARTITION  */
    MODIFY_PARTITION = 1030,       /* MODIFY_PARTITION  */
    ADD_SUBPARTITION = 1031,       /* ADD_SUBPARTITION  */
    DROP_SUBPARTITION = 1032,      /* DROP_SUBPARTITION  */
    NOT_ENFORCED = 1033,           /* NOT_ENFORCED  */
    VALID_BEGIN = 1034,            /* VALID_BEGIN  */
    DECLARE_CURSOR = 1035,         /* DECLARE_CURSOR  */
    ON_UPDATE_TIME = 1036,         /* ON_UPDATE_TIME  */
    START_WITH = 1037,             /* START_WITH  */
    CONNECT_BY = 1038,             /* CONNECT_BY  */
    END_OF_INPUT = 1039,           /* END_OF_INPUT  */
    END_OF_INPUT_COLON = 1040,     /* END_OF_INPUT_COLON  */
    END_OF_PROC = 1041,            /* END_OF_PROC  */
    EVENT_TRIGGER = 1042,          /* EVENT_TRIGGER  */
    NOT_IN = 1043,                 /* NOT_IN  */
    NOT_BETWEEN = 1044,            /* NOT_BETWEEN  */
    NOT_LIKE = 1045,               /* NOT_LIKE  */
    NOT_ILIKE = 1046,              /* NOT_ILIKE  */
    NOT_SIMILAR = 1047,            /* NOT_SIMILAR  */
    FORCE_INDEX = 1048,            /* FORCE_INDEX  */
    USE_INDEX = 1049,              /* USE_INDEX  */
    IGNORE_INDEX = 1050,           /* IGNORE_INDEX  */
    PARTIAL_EMPTY_PREC = 1051,     /* PARTIAL_EMPTY_PREC  */
    POSTFIXOP = 1052,              /* POSTFIXOP  */
    lower_than_index = 1053,       /* lower_than_index  */
    UMINUS = 1054,                 /* UMINUS  */
    EMPTY_FROM_CLAUSE = 1055       /* EMPTY_FROM_CLAUSE  */
  };
  typedef enum yytokentype yytoken_kind_t;
#endif

/* Value type.  */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
union YYSTYPE
{
#line 564 "preproc.y"

	double	dval;
	char	*str;
	int		ival;
	struct	when		action;
	struct	index		index;
	int		tagname;
	struct	this_type	type;
	enum	ECPGttype	type_enum;
	enum	ECPGdtype	dtype_enum;
	struct	fetch_desc	descriptor;
	struct  su_symbol	struct_union;
	struct	prep		prep;

#line 879 "preproc.hpp"

};
typedef union YYSTYPE YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif

/* Location type.  */
#if ! defined YYLTYPE && ! defined YYLTYPE_IS_DECLARED
typedef struct YYLTYPE YYLTYPE;
struct YYLTYPE
{
  int first_line;
  int first_column;
  int last_line;
  int last_column;
};
# define YYLTYPE_IS_DECLARED 1
# define YYLTYPE_IS_TRIVIAL 1
#endif


extern YYSTYPE base_yylval;
extern YYLTYPE base_yylloc;

int base_yyparse (void);


#endif /* !YY_BASE_YY_PREPROC_HPP_INCLUDED  */
