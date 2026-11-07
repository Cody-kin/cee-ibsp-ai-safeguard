# -*- coding: utf-8 -*
""" 
  @file  DFRobot_DF2301Q.py
  @note  DFRobot_DF2301Q Class infrastructure, implementation of underlying methods
  @copyright  Copyright (c) 2010 DFRobot Co.Ltd (http://www.dfrobot.com)
  @licence  The MIT License (MIT)
  @author  [qsjhyy](yihuan.huang@dfrobot.com)
  @version  V1.0
  @date  2022-12-30
  @url  https://github.com/DFRobot/DFRobot_DF2301Q
"""
# Local copy: comments/docstrings and UART debug log were removed in supplied source.
# Attribution restored; full license: ../../../licenses/DFRobot-MIT.txt
import sys
import time

import array
import smbus
import serial
import numpy as np

import logging
from ctypes import *

logger = logging.getLogger()
logger.setLevel(logging.FATAL)
ph = logging.StreamHandler()
formatter = logging.Formatter("%(asctime)s - [%(filename)s %(funcName)s]:%(lineno)d - %(levelname)s: %(message)s")
ph.setFormatter(formatter) 
logger.addHandler(ph)

## i2c address
DF2301Q_I2C_ADDR                  = 0x64

DF2301Q_I2C_REG_CMDID             = 0x02
DF2301Q_I2C_REG_PLAY_CMDID        = 0x03
DF2301Q_I2C_REG_SET_MUTE          = 0x04
DF2301Q_I2C_REG_SET_VOLUME        = 0x05
DF2301Q_I2C_REG_WAKE_TIME         = 0x06
DF2301Q_I2C_MSG_TAIL              = 0x5A

DF2301Q_UART_BAUDRATE             = 9600
DF2301Q_UART_MSG_DATA_MAX_SIZE    = 8
DF2301Q_UART_MSG_HEAD_LOW         = 0xF4
DF2301Q_UART_MSG_HEAD_HIGH        = 0xF5
DF2301Q_UART_MSG_HEAD             = 0xF5F4
DF2301Q_UART_MSG_TAIL             = 0xFB
DF2301Q_UART_MSG_TYPE_CMD_UP      = 0xA0
DF2301Q_UART_MSG_TYPE_CMD_DOWN    = 0xA1
DF2301Q_UART_MSG_TYPE_ACK         = 0xA2
DF2301Q_UART_MSG_TYPE_NOTIFY      = 0xA3

DF2301Q_UART_MSG_CMD_ASR_RESULT        = 0x91
DF2301Q_UART_MSG_CMD_PLAY_VOICE        = 0x92
DF2301Q_UART_MSG_CMD_GET_FLASHUID      = 0x93
DF2301Q_UART_MSG_CMD_GET_VERSION       = 0x94
DF2301Q_UART_MSG_CMD_RESET_MODULE      = 0x95
DF2301Q_UART_MSG_CMD_SET_CONFIG        = 0x96
DF2301Q_UART_MSG_CMD_ENTER_OTA_MODE    = 0x97
DF2301Q_UART_MSG_CMD_NOTIFY_STATUS     = 0x9A
DF2301Q_UART_MSG_CMD_ACK_COMMON        = 0xAA
DF2301Q_UART_MSG_CMD_USER_START        = 0xB0

DF2301Q_UART_MSG_DATA_PLAY_START            = 0x80
DF2301Q_UART_MSG_DATA_PLAY_PAUSE            = 0x81
DF2301Q_UART_MSG_DATA_PLAY_RESUME           = 0x82
DF2301Q_UART_MSG_DATA_PLAY_STOP             = 0x83
DF2301Q_UART_MSG_DATA_PLAY_BY_VOICEID       = 0x90
DF2301Q_UART_MSG_DATA_PLAY_BY_SEMANTIC_ID   = 0x91
DF2301Q_UART_MSG_DATA_PLAY_BY_CMD_ID        = 0x92

DF2301Q_UART_MSG_DATA_VER_PROTOCOL          = 0x80
DF2301Q_UART_MSG_DATA_VER_SDK               = 0x81
DF2301Q_UART_MSG_DATA_VER_ASR               = 0x82
DF2301Q_UART_MSG_DATA_VER_PREPROCESS        = 0x83
DF2301Q_UART_MSG_DATA_VER_PLAYER            = 0x84
DF2301Q_UART_MSG_DATA_VER_APP               = 0x8A

DF2301Q_UART_MSG_DATA_NOTIFY_POWERON        = 0xB0
DF2301Q_UART_MSG_DATA_NOTIFY_WAKEUPENTER    = 0xB1
DF2301Q_UART_MSG_DATA_NOTIFY_WAKEUPEXIT     = 0xB2
DF2301Q_UART_MSG_DATA_NOTIFY_PLAYSTART      = 0xB3
DF2301Q_UART_MSG_DATA_NOTIFY_PLAYEND        = 0xB4

DF2301Q_UART_MSG_CMD_SET_VOLUME             = 0x80
DF2301Q_UART_MSG_CMD_SET_ENTERWAKEUP        = 0x81
DF2301Q_UART_MSG_CMD_SET_PRT_MID_RST        = 0x82
DF2301Q_UART_MSG_CMD_SET_MUTE               = 0x83
DF2301Q_UART_MSG_CMD_SET_WAKE_TIME          = 0x84
DF2301Q_UART_MSG_CMD_SET_NEEDACK            = 0x90
DF2301Q_UART_MSG_CMD_SET_NEEDSTRING         = 0x91

DF2301Q_UART_MSG_ACK_ERR_NONE               = 0x00
DF2301Q_UART_MSG_ACK_ERR_CHECKSUM           = 0xff
DF2301Q_UART_MSG_ACK_ERR_NOSUPPORT          = 0xfe

class DFRobot_DF2301Q(object):
  def __init__(self):
    pass

class DFRobot_DF2301Q_I2C(DFRobot_DF2301Q):
  def __init__(self, i2c_addr=DF2301Q_I2C_ADDR, bus=1):
    self._addr = i2c_addr
    self._i2c = smbus.SMBus(bus)
    super(DFRobot_DF2301Q_I2C, self).__init__()

  def get_CMDID(self):
    time.sleep(0.05)
    return self._read_reg(DF2301Q_I2C_REG_CMDID)

  def play_by_CMDID(self, CMDID):
    self._write_reg(DF2301Q_I2C_REG_PLAY_CMDID, CMDID)
    time.sleep(1)

  def get_wake_time(self):
    return self._read_reg(DF2301Q_I2C_REG_WAKE_TIME)

  def set_wake_time(self, wake_time):
    wake_time = wake_time & 0xFF
    self._write_reg(DF2301Q_I2C_REG_WAKE_TIME, wake_time)

  def set_volume(self, vol):
    self._write_reg(DF2301Q_I2C_REG_SET_VOLUME, vol)

  def set_mute_mode(self, mode):
    if (0 != mode):
      mode = 1
    self._write_reg(DF2301Q_I2C_REG_SET_MUTE, mode)

  def _write_reg(self, reg, data):
    if isinstance(data, int):
      data = [data]
    self._i2c.write_i2c_block_data(self._addr, reg, data)

  def _read_reg(self, reg):
    data = self._i2c.read_i2c_block_data(self._addr, reg, 1)
    return data[0]

class DFRobot_DF2301Q_UART(DFRobot_DF2301Q):
  REV_STATE_HEAD0   = 0x00
  REV_STATE_HEAD1   = 0x01
  REV_STATE_LENGTH0 = 0x02
  REV_STATE_LENGTH1 = 0x03
  REV_STATE_TYPE    = 0x04
  REV_STATE_CMD     = 0x05
  REV_STATE_SEQ     = 0x06
  REV_STATE_DATA    = 0x07
  REV_STATE_CKSUM0  = 0x08
  REV_STATE_CKSUM1  = 0x09
  REV_STATE_TAIL    = 0x0a

  class uart_msg():
    def __init__(self):
      self.header = 0
      self.data_length = 0
      self.msg_type = 0
      self.msg_cmd = 0
      self.msg_seq = 0
      self.msg_data = [0] * 8

  def __init__(self):
    self.uart_cmd_ID = 0
    self._send_sequence = 0
    self._ser = serial.Serial("/dev/ttyAMA0", baudrate=DF2301Q_UART_BAUDRATE, bytesize=8, parity='N', stopbits=1, timeout=0.5)
    if self._ser.isOpen == False:
      self._ser.open()
    super(DFRobot_DF2301Q_UART, self).__init__()

  def get_CMDID(self):
    self._recv_packet()
    temp = self.uart_cmd_ID
    self.uart_cmd_ID = 0
    return temp

  def play_by_CMDID(self, play_id):
    msg = self.uart_msg()
    msg.header = DF2301Q_UART_MSG_HEAD
    msg.data_length = 6
    msg.msg_type = DF2301Q_UART_MSG_TYPE_CMD_DOWN
    msg.msg_cmd = DF2301Q_UART_MSG_CMD_PLAY_VOICE
    msg.msg_seq = self._send_sequence
    self._send_sequence += 1
    msg.msg_data[0] = DF2301Q_UART_MSG_DATA_PLAY_START
    msg.msg_data[1] = DF2301Q_UART_MSG_DATA_PLAY_BY_CMD_ID
    msg.msg_data[2] = play_id
    self._send_packet(msg)
    time.sleep(1)

  def reset_module(self):
    msg = self.uart_msg()
    msg.header = DF2301Q_UART_MSG_HEAD
    msg.data_length = 5
    msg.msg_type = DF2301Q_UART_MSG_TYPE_CMD_DOWN
    msg.msg_cmd = DF2301Q_UART_MSG_CMD_RESET_MODULE
    msg.msg_seq = self._send_sequence
    self._send_sequence += 1
    msg.msg_data[0] = 'r'
    msg.msg_data[1] = 'e'
    msg.msg_data[2] = 's'
    msg.msg_data[3] = 'e'
    msg.msg_data[4] = 't'
    self._send_packet(msg)
    time.sleep(3)

  def setting_CMD(self, set_type, set_value):
    msg = self.uart_msg()
    msg.header = DF2301Q_UART_MSG_HEAD
    msg.data_length = 5
    msg.msg_type = DF2301Q_UART_MSG_TYPE_CMD_DOWN
    msg.msg_cmd = DF2301Q_UART_MSG_CMD_SET_CONFIG
    msg.msg_seq = self._send_sequence
    self._send_sequence += 1
    msg.msg_data[0] = set_type
    msg.msg_data[1] = set_value
    self._send_packet(msg)

  def _send_packet(self, msg):
    chk_sum = 0x0000
    data = []
    data.append(msg.header & 0xFF)
    data.append((msg.header >> 8) & 0xFF)
    data.append(msg.data_length & 0xFF)
    data.append((msg.data_length >> 8) & 0xFF)
    data.append(msg.msg_type & 0xFF)
    chk_sum += msg.msg_type
    data.append(msg.msg_cmd & 0xFF)
    chk_sum += msg.msg_cmd
    data.append(msg.msg_seq & 0xFF)
    chk_sum += msg.msg_seq
    for i in range(0, msg.data_length):
      data.append(msg.msg_data[i] & 0xFF)
      chk_sum += msg.msg_data[i]
    data.append(chk_sum & 0xFF)
    data.append((chk_sum >> 8) & 0xFF)
    data.append(DF2301Q_UART_MSG_TAIL & 0xFF)
    self._ser.write(data)
    time.sleep(0.1)

  def _recv_packet(self):
    msg = self.uart_msg()
    rev_state = self.REV_STATE_HEAD0
    receive_char = 0
    chk_sum = 0
    data_rev_count = 0
    while self._ser.in_waiting:
      receive_char = ord(self._ser.read(1))
      if(self.REV_STATE_HEAD0 == rev_state):
        if(DF2301Q_UART_MSG_HEAD_LOW == receive_char):
          rev_state = self.REV_STATE_HEAD1
      elif(self.REV_STATE_HEAD1 == rev_state):
        if(DF2301Q_UART_MSG_HEAD_HIGH == receive_char):
          rev_state = self.REV_STATE_LENGTH0
          msg.header = DF2301Q_UART_MSG_HEAD
        else:
          rev_state = self.REV_STATE_HEAD0
      elif(self.REV_STATE_LENGTH0 == rev_state):
        msg.data_length = receive_char
        rev_state = self.REV_STATE_LENGTH1
      elif(self.REV_STATE_LENGTH1 == rev_state):
        msg.data_length += receive_char << 8
        rev_state = self.REV_STATE_TYPE
      elif(self.REV_STATE_TYPE == rev_state):
        msg.msg_type = receive_char
        rev_state = self.REV_STATE_CMD
      elif(self.REV_STATE_CMD == rev_state):
        msg.msg_cmd = receive_char
        rev_state = self.REV_STATE_SEQ
      elif(self.REV_STATE_SEQ == rev_state):
        msg.msg_seq = receive_char
        rev_state = rev_state
        if(msg.data_length > 0):
          rev_state = self.REV_STATE_DATA
          data_rev_count = 0
        else:
          rev_state = self.REV_STATE_CKSUM0
      elif(self.REV_STATE_DATA == rev_state):
        msg.msg_data[data_rev_count] = receive_char
        data_rev_count += 1
        if(msg.data_length == data_rev_count):
          rev_state = self.REV_STATE_CKSUM0
      elif(self.REV_STATE_CKSUM0 == rev_state):
        chk_sum = receive_char
        rev_state = self.REV_STATE_CKSUM1
      elif(self.REV_STATE_CKSUM1 == rev_state):
        chk_sum += receive_char << 8
        rev_state = self.REV_STATE_TAIL
      elif(self.REV_STATE_TAIL == rev_state):
        if(DF2301Q_UART_MSG_TAIL == receive_char):
          if(DF2301Q_UART_MSG_TYPE_CMD_UP == msg.msg_type):
            self.uart_cmd_ID = msg.msg_data[0]
        else:
          data_rev_count = 0
        rev_state = self.REV_STATE_HEAD0
      else:
        rev_state = self.REV_STATE_HEAD0
    return data_rev_count
