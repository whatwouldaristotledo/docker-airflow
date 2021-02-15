from airflow.models import DAG
from airflow.utils.dates import days_ago
from airflow.operators.python_operator import PythonOperator
from datetime import datetime
import pandas as pd
import urllib
import random
import cx_Oracle
import pyodbc 
import sqlalchemy


args={
    'owner': 'BI',
### start date is used to for the scheduler, the initial run date is the start_date plus 1 day, see documentation online for more information    
    'start_date': datetime(2021, 1 , 27),
    'retries':0

}
###schedule interval uses UTC time so, it is 8 hours ahead PST, if you want it to run 8am, you will need to put 16 in for the hours
### so 10 is really 2am PST
dag = DAG(dag_id='connect_to_oracle_or_sql', default_args=args, schedule_interval='0 8 * * *', catchup=False)


def sql_connect_with_cursor(**context):
    ###One way to connect to mssql using sql cursor
    sql_cnxn = pyodbc.connect('DRIVER={ODBC Driver 17 for SQL Server};SERVER=YourServer;DATABASE=Yourdb;UID=YourUserNameHere;PWD=YourUserPWHere')
    sql_cursor = sql_cnxn.cursor()
    data_x = sql_cursor.execute('EXEC Somestoredprocedure')
    sql_cnxn.close()

def connect_to_oracle(**connect):
    ##How to toconnect to oracle
    rs = cx_Oracle.makedsn('10.1.1.31', '1521', service_name='orcl')
    orcl_cnxn = cx_Oracle.connect(user=r'user', password='userpw', dsn=rs) 
    orcl_cnxn.close()

def sql_connect_with_alchemy_engine(**context):
    ###another way to connecto to Mssql using mssq_engine
    params = urllib.parse.quote_plus("Driver={ODBC Driver 17 for SQL Server};Server=YourServer;Database=Yourdb;UID=YourUserNameHere;PWD=YourUserPWHere;")
    mssql_engine = sqlalchemy.create_engine("mssql+pyodbc:///?odbc_connect={}".format(params))
    mssql_engine_cnxn = mssql_engine.connect()
    mssql_engine_cnxn.close()

with dag:
  run_this_task = PythonOperator(
    task_id='run_this',
    python_callable=connect_to_oracle,
    provide_context=True
  )
  run_this_task
    
