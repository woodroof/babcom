#!/bin/bash

readonly output=recreate.sql

truncate -s 0 "${output}";

pushd () {
  command pushd "$@" > /dev/null
}

popd () {
  command popd "$@" > /dev/null
}

echo "-- Cleanup" >> "${output}"

for schema in *; do
  if [ -d "${schema}" ]; then
    if [[ "${schema}" != _* ]] ; then
      echo "drop schema if exists \"${schema}\" cascade;" >> "${output}"
    fi
  fi
done

pushd _extensions
for extension in *; do
  echo "drop schema if exists \"${extension}\" cascade;" >> "../${output}"
done
popd

echo "-- Schemas" >> "${output}"

for schema in *; do
  if [ -d "${schema}" ]; then
    if [[ "${schema}" != _* ]] ; then
      echo "create schema \"${schema}\";" >> "${output}"
    fi
  fi
done

echo "-- Extensions" >> "${output}"

pushd _extensions
for extension in *; do
  echo "create schema \"${extension}\";" >> "../${output}"
  echo "create extension \"${extension}\" schema \"${extension}\";" >> "../${output}"
done
popd

echo "-- Privileges"
echo "grant usage on schema api to http;" >> "${output}";

echo "-- Types" >> "${output}"

for schema in *; do
  if [ -d "${schema}" ]; then
    if [[ "${schema}" != _* ]] ; then
      pushd "${schema}"
      egrep -lir "create type" | while read -r file; do
        cat "${file}" >> "../${output}"
      done
      popd
    fi
  fi
done

echo "-- Functions" >> "${output}"

for schema in *; do
  if [ -d "${schema}" ]; then
    if [[ "${schema}" != _* ]] ; then
      pushd "${schema}"
      egrep -lir "create or replace function" | while read -r file; do
        cat "${file}" >> "../${output}"
      done
      popd
    fi
  fi
done

echo "-- Tables" >> "${output}"

for schema in *; do
  if [ -d "${schema}" ]; then
    if [[ "${schema}" != _* ]] ; then
      pushd "${schema}"
      egrep -lir "create table" | xargs -r grep -Li "foreign" | while read -r file; do
        cat "${file}" >> "../${output}"
      done
      popd
    fi
  fi
done

for schema in *; do
  if [ -d "${schema}" ]; then
    if [[ "${schema}" != _* ]] ; then
      pushd "${schema}"
      egrep -lir "create table" | xargs -r grep -li "foreign" | while read -r file; do
        cat "${file}" >> "../${output}"
      done
      popd
    fi
  fi
done

echo "-- Initial data" >> "${output}"

cat initial_data.sql >> "${output}"