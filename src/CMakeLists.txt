# Copyright 2014 Carnegie Mellon University
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cmake_minimum_required(VERSION 2.6)

# basic configuration
if(CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_CURRENT_BINARY_DIR)
	message(FATAL_ERROR "Use out-of-source build only!")
endif(CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_CURRENT_BINARY_DIR)

project(MEHCACHED)

FIND_PACKAGE(PkgConfig REQUIRED)

PKG_CHECK_MODULES(LIBDPDK REQUIRED IMPORTED_TARGET libdpdk)

add_subdirectory(perf_count)
set(LIBRARY_PATH ${LIBRARY_PATH} perf_count/)

# compiler options
add_definitions(-pthread)
add_definitions(-g -Wall -Wextra -Wsign-conversion -Winline -Wno-unused-function)
add_definitions(-Wconversion)
add_definitions(-O9)
add_definitions(-msse4.2 -march=corei7)

# preprocessor
SET(NDEBUG "$ENV{NDEBUG}" CACHE STRING "define NDEBUG macro")

message(STATUS "NDEBUG (disable all additional checkings; no*, yes) = ${NDEBUG}")
if("${NDEBUG}" STREQUAL "yes")
	add_definitions(-DNDEBUG)
endif()

SET(NLOCAL "$ENV{NLOCAL}" CACHE STRING "no local programs")
SET(NCLIENT "$ENV{NCLIENT}" CACHE STRING "no clients")
SET(NSERVER "$ENV{NSERVER}" CACHE STRING "no servers")

message(STATUS "NLOCAL (do not compile local programs; no*, yes) = ${NLOCAL}")
message(STATUS "NCLIENT (do not compile clients; no*, yes) = ${NCLIENT}")
message(STATUS "NSERVER (do not compile server; no*, yes) = ${NSERVER}")

# common source files
set(SOURCES ${SOURCES} hash.c)
set(SOURCES ${SOURCES} city.c)
set(SOURCES ${SOURCES} stopwatch.c)
set(SOURCES ${SOURCES} shm.c)
set(SOURCES ${SOURCES} table.c)
set(SOURCES ${SOURCES} alloc_dynamic.c)
set(SOURCES ${SOURCES} alloc_pool.c)
set(SOURCES ${SOURCES} util.c)

# common libraries
set(LIBRARIES ${LIBRARIES} rt crypto perf_count m pthread)

# tcmalloc (optional)
#add_definitions(-fno-builtin-malloc -fno-builtin-calloc -fno-builtin-realloc -fno-builtin-free)
#set(LIBRARIES ${LIBRARIES} tcmalloc_minimal)

OPTION(DPDK "Enable Intel DPDK" ON)

# DPDK
IF(DPDK)

  MESSAGE(STATUS "DPDK support is enabled (to disable, run `cmake .. -DDPDK=OFF`)")
  add_definitions(-DUSE_DPDK)

  include_directories(${LIBDPDK_INCLUDE_DIRS})
  link_directories(${LINK_DIRECTORIES} ${LIBDPDK_LIBRARY_DIRS})
  
  set(LIBRARIES ${LIBRARIES} -Wl,--whole-archive)
  set(LIBRARIES ${LIBRARIES} rte_hash)
  set(LIBRARIES ${LIBRARIES} -Wl,--start-group)
  set(LIBRARIES ${LIBRARIES} rte_kvargs rte_mbuf rte_ethdev rte_mempool rte_mempool_ring rte_ring rte_net rte_pci rte_eal rte_bus_pci rte_telemetry)
  
  find_library(MLX5 rte_net_mlx5 HINTS /opt/mellanox/dpdk/lib/x86_64-linux-gnu)
  
  if (MLX5)
    MESSAGE(STATUS "Using mlx5 driver")
    set(LIBRARIES ${LIBRARIES} rte_common_mlx5 rte_net_mlx5 ibverbs mlx5 mnl dl)
  else(MLX5)
    MESSAGE(STATUS "Using Intel drivers")
    set(LIBRARIES ${LIBRARIES} rte_net_i40e rte_net_ice rte_net_ixgbe rte_net_ring)
  endif(MLX5)
  
  set(LIBRARIES ${LIBRARIES} -Wl,--end-group)
  set(LIBRARIES ${LIBRARIES} -Wl,--no-whole-archive)
  set(LIBRARIES ${LIBRARIES} rt)

ELSE(DPDK)

  MESSAGE(STATUS "Intel DPDK support is disabled (to enable, run `cmake .. -DDPDK=ON`)")

ENDIF(DPDK)

set(LIBRARIES ${LIBRARIES} pthread rt)	# to make sure symbols in pthread and rt are resolved

if(NOT "${NLOCAL}" STREQUAL "yes")
	# test
	add_executable(test test.c ${SOURCES})
	target_link_libraries(test ${LIBRARIES})

	# load
	add_executable(load load.c ${SOURCES})
	target_link_libraries(load ${LIBRARIES})

	# microbench
	add_executable(microbench microbench.c ${SOURCES})
	target_link_libraries(microbench ${LIBRARIES})

	# microbench_store
	add_executable(microbench_store microbench.c ${SOURCES})
	set_target_properties(microbench_store PROPERTIES COMPILE_FLAGS "-DMEHCACHED_NO_EVICTION")
	target_link_libraries(microbench_store ${LIBRARIES})

	# netbench_analysis
	add_executable(netbench_analysis netbench_config.c netbench_analysis.c ${SOURCES})
	target_link_libraries(netbench_analysis ${LIBRARIES})
endif()

if(NOT "${NCLIENT}" STREQUAL "yes")
	# netbench_client
	add_executable(netbench_client net_common.c netbench_config.c netbench_client.c ${SOURCES})
	target_link_libraries(netbench_client ${LIBRARIES})

	# netbench_client_latency
	add_executable(netbench_client_latency net_common.c netbench_config.c netbench_client.c ${SOURCES})
	set_target_properties(netbench_client_latency PROPERTIES COMPILE_FLAGS "-DMEHCACHED_MEASURE_LATENCY")
	target_link_libraries(netbench_client_latency ${LIBRARIES})

	# netbench_client_soft_fdir
	add_executable(netbench_client_soft_fdir net_common.c netbench_config.c netbench_client.c ${SOURCES})
	set_target_properties(netbench_client_soft_fdir PROPERTIES COMPILE_FLAGS "-DMEHCACHED_USE_SOFT_FDIR")
	target_link_libraries(netbench_client_soft_fdir ${LIBRARIES})
endif()

if(NOT "${NSERVER}" STREQUAL "yes")
	# netbench_server
	add_executable(netbench_server net_common.c netbench_config.c netbench_server.c ${SOURCES})
	target_link_libraries(netbench_server ${LIBRARIES})

	# netbench_server_latency
	add_executable(netbench_server_latency net_common.c netbench_config.c netbench_server.c ${SOURCES})
	set_target_properties(netbench_server_latency PROPERTIES COMPILE_FLAGS "-DMEHCACHED_MEASURE_LATENCY")
	target_link_libraries(netbench_server_latency ${LIBRARIES})

	# netbench_server_soft_fdir
	add_executable(netbench_server_soft_fdir net_common.c netbench_config.c netbench_server.c ${SOURCES})
	set_target_properties(netbench_server_soft_fdir PROPERTIES COMPILE_FLAGS "-DMEHCACHED_USE_SOFT_FDIR")
	target_link_libraries(netbench_server_soft_fdir ${LIBRARIES})

	# netbench_server_store
	add_executable(netbench_server_store net_common.c netbench_config.c netbench_server.c ${SOURCES})
	set_target_properties(netbench_server_store PROPERTIES COMPILE_FLAGS "-DMEHCACHED_NO_EVICTION")
	target_link_libraries(netbench_server_store ${LIBRARIES})
endif()
