# Build stage
FROM elixir:1.18.4-otp-28 AS build

COPY . /app

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get --only prod
RUN MIX_ENV=PROD mix release

EXPOSE 80

ENTRYPOINT ["sh", "-c", "./_build/PROD/rel/hackattic/bin/hackattic start"]