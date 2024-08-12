# conftest.py
import asyncio
from datetime import datetime
from unittest.mock import AsyncMock, MagicMock
import pytest
from asyncpg import create_pool
from app.components.mail_processor.process_wsg_status import store_wsg_status_reports


# Simulate an asyncpg Connection
async def mock_connection():
    connection = MagicMock()
    mock_cursor = AsyncMock()

    # Define a side effect function for fetch
    async def fetch_side_effect(query, *args, **kwargs):
        if query == "SELECT * FROM users":
            return [{"id": 1, "name": "John Doe"}, {"id": 2, "name": "Jane Doe"}]
        elif query == "SELECT * FROM products":
            return [{"id": 1, "name": "Laptop"}, {"id": 2, "name": "Smartphone"}]
        return [{"exists": True}]

    # Define a side effect function for fetchrow
    async def fetchrow_side_effect(query, *args, **kwargs):
        if query == "SELECT * FROM users WHERE id=1":
            return {"id": 1, "name": "John Doe"}
        elif query == "SELECT * FROM products WHERE id=1":
            return {"id": 1, "name": "Laptop"}
        return False

    # Assign side effects to the mock methods
    mock_cursor.fetch.side_effect = fetch_side_effect
    mock_cursor.fetchrow.side_effect = fetchrow_side_effect
    mock_cursor.execute.return_value = None

    # Assign the mock methods to the connection
    connection.fetch = mock_cursor.fetch
    connection.fetchrow = mock_cursor.fetchrow
    connection.execute = mock_cursor.execute

    return connection


@pytest.mark.asyncio
async def test_sql_queries(pg_pool):
    async with pg_pool.acquire() as connection:
        await connection.execute(
            "CREATE TABLE users (id serial PRIMARY KEY, name text)"
        )
        await connection.execute("INSERT INTO users (name) VALUES ($1)", "John Doe")
        await connection.execute("INSERT INTO users (name) VALUES ($1)", "Jane Doe")

        rows = await connection.fetch("SELECT * FROM users")
        assert len(rows) == 2
        assert rows[0].get("name") == "John Doe"
        assert rows[1].get("name") == "Jane Doe"

        row = await connection.fetchrow("SELECT * FROM users WHERE id=1")
        assert row.get("id") == 1
        assert row.get("name") == "John Doe"


# Example usage of the mock connection
@pytest.mark.asyncio
async def test_query():
    connection = await mock_connection()

    # Simulate a fetch operation
    # rows = await connection.fetch("SELECT * FROM users")
    # print(rows)

    # # Simulate a fetchrow operation
    # row = await connection.fetchrow("SELECT * FROM users WHERE id=1")
    # print(row)

    # # Simulate an execute operation
    # await connection.execute("INSERT INTO users (name) VALUES ($1)", "Alice")
    await store_wsg_status_reports(
        connection=connection,
        wsg_status_report_payload=b"test",
        filename="test.txt",
        mail_uid="123",
        mail_timestamp=datetime.now(),
        attachment_id=1,
    )


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.get_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
async def pg_pool(postgresql):
    pool = await create_pool(
        user=postgresql.info.user,
        password=postgresql.info.password,
        database=postgresql.info.dbname,
        host=postgresql.info.host,
        port=postgresql.info.port,
    )
    yield pool
    await pool.close()


# Run the test
asyncio.run(test_query())
