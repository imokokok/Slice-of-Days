FROM python:3.13-slim
WORKDIR /app
RUN pip install --no-cache-dir gunicorn==23.0.0
COPY app.py /app/app.py
RUN useradd --uid 10001 --create-home postoffice && mkdir /data && chown postoffice /data
USER postoffice
ENV COLLAGE_DB=/data/letters.sqlite3
VOLUME ["/data"]
EXPOSE 8787
CMD ["gunicorn", "--bind", "0.0.0.0:8787", "--workers", "1", "--threads", "8", "--timeout", "30", "app:application"]
