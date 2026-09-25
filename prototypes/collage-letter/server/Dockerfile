FROM python:3.13-slim
WORKDIR /app
COPY app.py /app/app.py
COPY vendor /app/vendor
RUN useradd --uid 10001 --create-home postoffice && mkdir /data && chown postoffice /data
USER postoffice
ENV COLLAGE_DB=/data/letters.sqlite3
VOLUME ["/data"]
EXPOSE 8787
CMD ["python", "app.py", "--host", "0.0.0.0", "--port", "8787"]
