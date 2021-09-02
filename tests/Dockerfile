ARG IMAGE_TAG
ARG FUNCTION_DIR="/work"

FROM ${IMAGE_TAG} AS builder

RUN mkdir -p /work

WORKDIR /work

COPY index.ts package.json tsconfig.json /work/

RUN npm i -g npm \
 && npm i -g yarn \
 && yarn build

FROM ${IMAGE_TAG}

ARG FUNCTION_DIR

ENV LAMBDA_TASK_ROOT=/var/task

RUN mkdir -p ${FUNCTION_DIR}

COPY --from=builder /work/index.js /work/package.json ${FUNCTION_DIR}/

WORKDIR ${FUNCTION_DIR}
RUN yarn install --production

ENTRYPOINT [ "/var/task/bootstrap" ]
CMD [ "index.handler" ]
