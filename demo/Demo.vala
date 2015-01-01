/*
 * ev3dev-lang-vala - vala library for interacting with LEGO MINDSTORMS EV3
 * hardware on bricks running ev3dev
 *
 * Copyright 2014 David Lechner <david@lechnology.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 */

namespace EV3DevLang {
    public class Demo : Application {
        DeviceManager manager;
        Port? selected_port;
        Sensor? selected_sensor;

        Demo () {
            Object (application_id: "org.ev3dev.ev3dev-lang-vala-demo",
                flags: ApplicationFlags.HANDLES_COMMAND_LINE);
            manager = new DeviceManager ();
            manager.port_added.connect (on_port_added);
            manager.get_ports ().foreach (on_port_added);
            manager.sensor_added.connect (on_sensor_added);
            manager.get_sensors ().foreach (on_sensor_added);
        }

        void print_menu_items<T> (ApplicationCommandLine command_line) {
            var enum_class = (EnumClass) typeof (T).class_ref ();
            command_line.print ("\n");
            foreach (var enum_value in enum_class.values) {
                var text = enum_value.value_nick.replace ("-", " ");
                command_line.print ("%d. %s\n", enum_value.value, text);
            }
        }

        async int get_input (ApplicationCommandLine command_line,
            DataInputStream stdin) throws IOError
        {
            command_line.print ("\nSelect an item: ");
            return int.parse (yield stdin.read_line_async ());
        }

        enum MainMenu {
            PORTS = 1,
            SENSORS,
            QUIT
        }

        async void do_main_menu (ApplicationCommandLine command_line) throws IOError {
            var stdin = new DataInputStream (command_line.get_stdin ());
            // Main Menu
            var done = false;
            while (!done) {
                print_menu_items<MainMenu> (command_line);
                switch (yield get_input (command_line, stdin)) {
                case MainMenu.PORTS:
                    yield do_ports_menu (command_line, stdin);
                    break;
                case MainMenu.SENSORS:
                    yield do_sensors_menu (command_line, stdin);
                    break;
                case MainMenu.QUIT:
                    done = true;
                    break;
                default:
                    command_line.print ("Invalid selection.\n");
                    break;
                }
            }
        }

        enum PortsMenu {
            SELECT_PORT = 1,
            SHOW_PORT_INFO,
            SELECT_MODE,
            SET_DEVICE,
            MAIN_MENU
        }

        async void do_ports_menu (ApplicationCommandLine command_line,
            DataInputStream stdin) throws IOError
        {
            var done = false;
            while (!done) {
                print_menu_items<PortsMenu> (command_line);
                switch (yield get_input (command_line, stdin)) {
                case PortsMenu.SELECT_PORT:
                    yield do_select_port (command_line, stdin);
                    break;
                case PortsMenu.SHOW_PORT_INFO:
                    do_show_port_info (command_line);
                    break;
                case PortsMenu.SELECT_MODE:
                    yield do_select_port_mode (command_line, stdin);
                    break;
                case PortsMenu.SET_DEVICE:
                    yield do_port_set_device (command_line, stdin);
                    break;
                case PortsMenu.MAIN_MENU:
                    done = true;
                    break;
                default:
                    command_line.print ("Invalid selection.\n");
                    break;
                }
            }
        }

        async void do_select_port (ApplicationCommandLine command_line,
            DataInputStream stdin) throws IOError
        {
            var ports = manager.get_ports ();
            int i = 1;
            ports.foreach ((port) => {
                command_line.print ("%d. %s\n", i, port.name);
                i++;
            });
            command_line.print ("\nSelect Port: ");
            var input = int.parse (yield stdin.read_line_async ());
            if (input <= 0 || input >= i)
                command_line.print ("Invalid Selection.\n");
            else
                selected_port = ports[input - 1];
        }

        void do_show_port_info (ApplicationCommandLine command_line) {
            command_line.print ("\n");
            if (selected_port == null) {
                command_line.print ("No port selected.\n");
                return;
            }
            command_line.print ("port name: %s\n", selected_port.name);
            command_line.print ("\tmodes: %s\n", string.joinv (", ", selected_port.modes));
            command_line.print ("\tmode: %s\n", selected_port.mode);
            command_line.print ("\tstatus: %s\n", selected_port.status);
        }

        async void do_select_port_mode (ApplicationCommandLine command_line,
            DataInputStream stdin) throws IOError
        {
            if (selected_port == null) {
                command_line.print ("No port selected.\n");
                return;
            }
            int i = 1;
            foreach (var mode in selected_port.modes) {
                command_line.print ("%d. %s\n", i, mode);
                i++;
            }
            command_line.print ("\nSelect Mode: ");
            var cancellable = new Cancellable ();
            var handler_id = selected_port.notify["connected"].connect (() => {
                cancellable.cancel ();
            });
            var input = int.parse (yield stdin.read_line_async (Priority.DEFAULT, cancellable));
            SignalHandler.disconnect (selected_port, handler_id);
            if (input <= 0 || input >= i) {
                command_line.print ("Invalid Selection.\n");
            } else {
                try {
                    selected_port.set_mode (selected_port.modes[input - 1]);
                } catch (Error err) {
                    command_line.print ("Error: %s\n", err.message);
                }
            }
        }

        async void do_port_set_device (ApplicationCommandLine command_line,
            DataInputStream stdin) throws IOError
        {
            if (selected_port == null) {
                command_line.print ("No port selected.\n");
                return;
            }
            command_line.print ("\nEnter Device Name: ");
            var cancellable = new Cancellable ();
            var handler_id = selected_port.notify["connected"].connect (() => {
                cancellable.cancel ();
            });
            var input = yield stdin.read_line_async (Priority.DEFAULT, cancellable);
            SignalHandler.disconnect (selected_port, handler_id);
            try {
                selected_port.set_device (input);
            } catch (Error err) {
                command_line.print ("Error: %s\n", err.message);
            }
        }

        enum SensorsMenu {
            SELECT_SENSOR = 1,
            MAIN_MENU
        }

        async void do_sensors_menu (ApplicationCommandLine command_line,
            DataInputStream stdin) throws IOError
        {
            var done = false;
            while (!done) {
                print_menu_items<SensorsMenu> (command_line);
                switch (yield get_input (command_line, stdin)) {
                case SensorsMenu.SELECT_SENSOR:
                    yield do_select_sensor (command_line, stdin);
                    break;
                case SensorsMenu.MAIN_MENU:
                    done = true;
                    break;
                default:
                    command_line.print ("Invalid selection.\n");
                    break;
                }
            }
        }

        async void do_select_sensor (ApplicationCommandLine command_line,
            DataInputStream stdin) throws IOError
        {
            var sensors = manager.get_sensors ();
            int i = 1;
            sensors.foreach ((sensor) => {
                command_line.print ("%d. %s on %s\n", i, sensor.device_name,
                    sensor.port_name);
                i++;
            });
            command_line.print ("\nSelect Sensor: ");
            var input = int.parse (yield stdin.read_line_async ());
            if (input <= 0 || input >= i)
                command_line.print ("Invalid Selection.\n");
            else
                selected_sensor = sensors[input - 1];
        }

        public override int command_line (ApplicationCommandLine command_line) {
            hold ();
            do_main_menu.begin (command_line, (obj, res) => {
                try {
                    do_main_menu.end (res);
                } catch (IOError err) {
                    command_line.print (err.message);
                }
                release ();
            });
            return 0;
        }

        static int main (string[] args) {
            var demo = new Demo ();
            return demo.run (args);
        }

        void on_port_added (Port port) {
             message ("Port added: %s", port.name);
        }

        void on_sensor_added (Sensor sensor) {
             info ("Sensor added: %s", sensor.device_name);
             info ("\tport_name: %s", sensor.port_name);
             info ("\tmodes: %s", string.joinv (", ", sensor.modes));
             info ("\tmode: %s", sensor.mode);
             info ("\tcommands: %s", string.joinv (", ", sensor.commands));
             info ("\tnum_values: %d", sensor.num_values);
             info ("\tdecimals: %d", sensor.decimals);
             info ("\tunits: %s", sensor.units);
             var values = new string[sensor.num_values];
             for (int i = 0; i < sensor.num_values; i++)
                values[i] = sensor.get_float_value (i).to_string ();
            info ("\tvalues: %s", string.joinv(", ", values));
        }
    }
}