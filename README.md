# sd-usedcardealer
sd-usedcardealer is a comprehensive used car dealership system for FiveM that allows players to list their vehicles for sale at various dealer locations with features including test drives, commission-free sales, dealer capacity management, and more.

This is not a simple plug and play resource, it will require modification of the server-side to function for your specific use-case/server. Support will not be provided.

## Features
- 🚗 **List Your Vehicles** - Players can list their owned vehicles for sale at dealer locations
- 🏪 **Multiple Dealerships** - Support for multiple dealer locations across the map
- 🚘 **Test Drives** - Potential buyers can test drive vehicles before purchasing (2-minute timer)
- 💰 **Direct Sales** - Sellers receive full payment directly to their bank account
- 📊 **Dealer Capacity** - Each dealership has limited display spots for vehicles
- 🔄 **Real-time Updates** - Vehicle displays refresh automatically when listings change
- 📝 **Listing Management** - Update prices or remove listings at any time
- 🌍 **Framework Bridge** - Works with both QBCore/QBX and ESX
- 🏦 **Banking Integration** - Direct bank transfers for vehicle sales
- 📏 **Mileage Display** - Shows vehicle mileage if jg-vehiclemileage is installed

## Preview
![FiveM_GTAProcess_t2p8CsdyaS](https://github.com/user-attachments/assets/4a43ef9c-842b-4cb7-a4e3-8d08a3c65129)
![FiveM_GTAProcess_IxKHtAm1i5](https://github.com/user-attachments/assets/3cfa992c-da85-4536-a781-49b2803b8527)
![FiveM_GTAProcess_qnmap8zFWq](https://github.com/user-attachments/assets/023a9291-0c63-4374-8bfa-3578ce14813f)

## 🔔 Contact
Author: Samuel#0008  
Discord: [Join the Discord](https://discord.gg/FzPehMQaBQ)  
Store: [Click Here](https://fivem.samueldev.shop)

## 💾 Installation
1. Download the latest release from the repository
2. Extract the downloaded file and rename the folder to `sd-usedcardealer`
3. Place the `sd-usedcardealer` folder into your server's `resources` directory
4. Import the SQL table (auto-creates on first start, but you can manually create if needed):
```sql
CREATE TABLE IF NOT EXISTS usedcar_listings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_id VARCHAR(255) NOT NULL,
    location_id VARCHAR(50) NOT NULL,
    data JSON NOT NULL,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_seller (seller_id),
    INDEX idx_location (location_id),
    INDEX idx_active (active)
);
```
5. Add `ensure sd-usedcardealer` to your `server.cfg`
6. Configure the banking functions in `server/sv_main.lua` (lines 14-37) for your banking system
7. Adjust dealer locations and settings in `config.lua`

## 📖 Dependencies
### Required
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- [ox_target](https://github.com/overextended/ox_target)
- [qbx_core](https://github.com/Qbox-project/qbx_core), [qb-core](https://github.com/qbcore-framework/qb-core) or [es_extended](https://github.com/esx-framework)

### Optional (for enhanced features)
- [jg-vehiclemileage](https://github.com/JG-Docs/jg-vehiclemileage) - For displaying vehicle mileage
- [qbx_vehiclekeys](https://github.com/Qbox-project/qbx_vehiclekeys) - For vehicle key management
- Your banking system (configured in server/sv_main.lua)

## 📖 Configuration

### Banking System Setup
The script requires a banking system that supports account identifiers (IBAN, account numbers) for direct transfers.

Edit the banking functions in `server/sv_main.lua` (lines 14-37):

```lua
-- Example Integration with RxBanking
Banking.GetPlayerAccount = function(identifier)
    local accountData = exports['RxBanking']:GetPlayerPersonalAccount(identifier)
    if type(accountData) == "table" then
        return accountData.iban
    elseif type(accountData) == "string" then
        return accountData
    end
    return nil
end

```
