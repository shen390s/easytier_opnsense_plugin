<?php

/*
 * Copyright (C) 2024 EasyTier OPNsense Plugin
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

function easytier_enabled()
{
    $mdl = new \OPNsense\EasyTier\EasyTier();
    return (string)$mdl->general->enabled == '1';
}

function easytier_interfaces()
{
    $interfaces = [];

    if (easytier_enabled()) {
        $interfaces['easytier'] = [
            'descr' => gettext('EasyTier (Group)'),
            'if' => 'easytier',
            'virtual' => true,
            'enable' => true,
            'type' => 'group',
            'networks' => [],
        ];
        $interfaces['easytier0'] = [
            'descr' => gettext('EasyTier'),
            'if' => 'easytier0',
            'virtual' => true,
            'enable' => true,
            'type' => 'none',
            'networks' => [],
        ];
    }

    return $interfaces;
}

function easytier_firewall(\OPNsense\Firewall\Plugin $fw)
{
    if (easytier_enabled()) {
        $fw->registerFilterRule(
            1,
            [
                'interface' => 'easytier0',
                'descr' => 'EasyTier - allow all traffic on EasyTier interface',
                'direction' => 'in',
                '#ref' => 'ui/vpn/easytier',
            ],
            ['type' => 'pass']
        );
        $fw->registerFilterRule(
            1,
            [
                'interface' => 'easytier0',
                'descr' => 'EasyTier - allow all outbound traffic on EasyTier interface',
                'direction' => 'out',
                '#ref' => 'ui/vpn/easytier',
            ],
            ['type' => 'pass']
        );
    }
}

function easytier_services()
{
    $services = [];

    if (easytier_enabled()) {
        $services[] = [
            'description' => gettext('EasyTier VPN'),
            'configd' => [
                'start' => ['easytier start'],
                'stop' => ['easytier stop'],
                'restart' => ['easytier restart'],
                'configure' => ['easytier reconfigure'],
            ],
            'name' => 'easytier',
            'pidfile' => '/var/run/easytier.pid',
        ];
    }

    return $services;
}


