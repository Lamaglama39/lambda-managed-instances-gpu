# タグは差し替えられる可能性があるため、AWS公式のLambdaベースイメージをダイジェストで固定する。
# 更新するときはダイジェストを確認してからBASE_IMAGE(Terraformのvar.base_image)を変える。
ARG BASE_IMAGE=public.ecr.aws/lambda/python:3.13@sha256:f997db32f844709767d5dae2c1767a93797fc88e2f15c4075e3e50866368213d
FROM ${BASE_IMAGE}

COPY requirements.txt ${LAMBDA_TASK_ROOT}/

# requirements.txtはuvで生成した全依存のハッシュ付きロック(生成方法はpyproject.tomlとREADMEを参照)。
# --require-hashesでロックと異なるファイルを拒否し、--no-depsでロック外のパッケージを入れない。
# --only-binaryでビルド時にsetup.pyなどの任意コードが走らないようにする。
RUN pip install --no-cache-dir --require-hashes --no-deps --only-binary=:all: \
      --index-url https://pypi.org/simple \
      -r ${LAMBDA_TASK_ROOT}/requirements.txt

COPY handler.py ${LAMBDA_TASK_ROOT}/

CMD ["handler.handler"]
