#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>
#include <sys/socket.h>

typedef void (*DataAvailableCallback)(int socket_fd, const uint8_t *data,
                                      size_t length, void *ctx);
typedef void (*ConnectCallback)(int socket_fd, bool success, void *ctx);

int socket_create(int type);

int socket_bind(int socket_fd, int port);

int socket_connect(int socket_fd, const char *host, int port,
                   ConnectCallback connect_callback);

void socket_accept(int socket_fd,
                   DataAvailableCallback data_available_callback);

void socket_send(int socket_fd, const uint8_t *data, size_t length);

void socket_close(int socket_fd);

void socket_event_loop_run();

void socket_event_loop_stop();
