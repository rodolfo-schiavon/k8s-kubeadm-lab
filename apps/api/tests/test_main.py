from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_healthz():
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@patch("main.ping_db", return_value=True)
def test_readyz_ok(mock_ping):
    response = client.get("/readyz")
    assert response.status_code == 200
    assert response.json()["database"] == "connected"
    mock_ping.assert_called_once()


@patch("main.ping_db", return_value=False)
def test_readyz_unavailable(mock_ping):
    response = client.get("/readyz")
    assert response.status_code == 503
    mock_ping.assert_called_once()


@patch("main.ensure_db")
@patch("main.get_conn")
def test_list_items(mock_get_conn, mock_ensure_db):
    mock_cur = MagicMock()
    mock_cur.fetchall.return_value = [{"id": 1, "title": "alpha"}]
    mock_conn = MagicMock()
    mock_conn.cursor.return_value.__enter__.return_value = mock_cur
    mock_get_conn.return_value.__enter__.return_value = mock_conn

    response = client.get("/api/items")
    assert response.status_code == 200
    assert response.json() == [{"id": 1, "title": "alpha"}]
    mock_ensure_db.assert_called_once()


@patch("main.ensure_db")
@patch("main.get_conn")
def test_create_item(mock_get_conn, mock_ensure_db):
    mock_cur = MagicMock()
    mock_cur.fetchone.return_value = {"id": 2, "title": "beta"}
    mock_conn = MagicMock()
    mock_conn.cursor.return_value.__enter__.return_value = mock_cur
    mock_get_conn.return_value.__enter__.return_value = mock_conn

    response = client.post("/api/items", json={"title": "beta"})
    assert response.status_code == 200
    assert response.json() == {"id": 2, "title": "beta"}
    mock_ensure_db.assert_called_once()
